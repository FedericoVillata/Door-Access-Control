from flask import Flask, request, jsonify
import mysql.connector
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import jwt
import datetime
import re
import smtplib
from functools import wraps
import logging
#from werkzeug.security import generate_password_hash, check_password_hash
import hashlib
import scripts.regex as rex
import scripts.mail as mymail 
from revisited import *

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)

db = mysql.connector.connect( 
    host="localhost",
    user="root",
    password="",
    database="aziendaDB"
)




def check_room_access_revisited(current_username, room_name, company_name, user_role):
    # function reused, by check_room_access
    # data = request.json
    # room_name = data.get('roomName')
    # company_name = data.get('companyName')
    # user_role = data.get('role')

    if not room_name or not company_name or not user_role:
        return {'message': 'Missing required parameters', 'id' : 400 }

    cursor = db.cursor()
    print("ok_filippo")
    try:
        # Controllo se l'utente ha un record specifico nella stanza
        query = """
            SELECT allowed_denied FROM rooms 
            WHERE companyName = %s AND roomName = %s AND username = %s
        """
        cursor.execute(query, (company_name, room_name, current_username))
        result = cursor.fetchone()

        if result:
            print(result)
            allowed_denied = result[0]
            if allowed_denied:
                return {'message': 'Access granted', 'id': 200 }
            else:
                return {'message': 'Access denied', 'id': 403 }
        else:
            print("nah")
            # Controllo se c'è un ruolo associato alla stanza
            query = """
                SELECT allowed_denied, username FROM rooms 
                WHERE companyName = %s AND roomName = %s AND username IN ('ALL', %s)
            """
            cursor.execute(query, (company_name, room_name, user_role))
            result = cursor.fetchall()

            if result:
                for row in result:
                    allowed_denied = row[0]
                    role_in_db = row[1]
                    if role_in_db == 'ALL' and allowed_denied:
                        return {'message': 'Access granted', "id": 200}
                    if role_in_db == user_role and allowed_denied:
                        if user_role == 'USR' or (user_role == 'CO' and row[1] in ['CO', 'CA', 'SA']) or (user_role == 'CA' and row[1] in ['CA', 'SA']):
                            return {'message': 'Access granted', "id": 200}
                        else:
                            return {'message': 'Access denied', "id": 403 }
                return {'message': 'Access denied', "id": 403 }
            else:
                return {'message': 'Access denied', "id": 403 }
    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return {'message': f'Error: {err}', "id": 500 }
    except Exception as e:
        print(f"Unexpected Error: {e}")
        return {'message': f'Unexpected Error: {e}', "id": 500 }
    finally:
        cursor.close()
        

def check_in_revisited(username, companyName, room):
    # data = request.json
    # print("Request Data:", data)  # Aggiungi questo per vedere i dati ricevuti
    # username = data.get('username')
    # companyName = data.get('companyName')
    # room = data.get('room')
    check_in_time = datetime.datetime.now()

    if not username or not companyName or not room:
        return {'message': 'Missing required parameters', "id": 403 }

    cursor = db.cursor(buffered=True)

    try:
        # Verifica se esiste un record per l'utente e l'azienda nella tabella permission
        query = "SELECT room, check_in FROM permission WHERE username = %s"
        cursor.execute(query, [username])
        result = cursor.fetchone()
        
        if result:
            previous_room, previous_check_in = result
            if previous_room != 'Hall':
                # Calcola il tempo trascorso nella stanza precedente
                check_out_time = datetime.datetime.now()
                time_in_room = check_out_time - previous_check_in

                # Inserisce o aggiorna un record nella tabella log
                insert_log_query = """
                INSERT INTO log (username, companyName, room, check_out, time_in_room)
                VALUES (%s, %s, %s, %s, %s)
                ON DUPLICATE KEY UPDATE
                    check_out = VALUES(check_out),
                    time_in_room = VALUES(time_in_room)
                """
                cursor.execute(insert_log_query, (username, companyName, previous_room, check_out_time, str(time_in_room)))
                db.commit()

        # Inserisci o aggiorna il check-in
        insert_permission_query = """
        INSERT INTO permission (username, companyName, room, check_in)
        VALUES (%s, %s, %s, %s)
        ON DUPLICATE KEY UPDATE
            room = VALUES(room),
            check_in = VALUES(check_in)
        """
        cursor.execute(insert_permission_query, (username, companyName, room, check_in_time))
        db.commit()
        return {'message': 'Check-in recorded/updated successfully', "id" : 200 }
    except mysql.connector.Error as err:
        db.rollback()
        print(f"Database Error: {err}")
        return {'message': f'Error: {err}', "id" : 500 }
    except Exception as e:
        db.rollback()
        print(f"Unexpected Error: {e}")
        return {'message': f'Unexpected Error: {e}', "id" : 500 }
    finally:
        cursor.close()



def move_to_room_w_log(username, companyName, room):
    check_in_time = datetime.datetime.now()

    if not username or not companyName or not room:
        return {'message': 'Missing required parameters', 'id': 403}
    
    # Connessione al database
    db = mysql.connector.connect(
        host="your_host",
        user="your_user",
        password="your_password",
        database="your_database"
    )
    cursor = db.cursor(buffered=True)

    try:
        # Verifica se esiste un record per l'utente nella tabella permission
        query_check = "SELECT * FROM permission WHERE username = %s"
        cursor.execute(query_check, [username])
        result = cursor.fetchone()

        if result:
            # Aggiorna la riga con i nuovi valori
            query_update = """
                UPDATE permission
                SET room = %s, companyName = %s, check_in = %s
                WHERE username = %s
            """
            cursor.execute(query_update, (room, companyName, check_in_time, username))
            db.commit()
            return {'message': 'Record updated successfully', 'id': 200}
        else:
            return {'message': 'User not found', 'id': 404}

    except mysql.connector.Error as err:
        return {'message': f'Error: {err}', 'id': 500}
    
    finally:
        cursor.close()
        db.close()


if __name__ == '__main__':
    app.run(debug=True) 