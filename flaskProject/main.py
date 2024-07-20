from flask import Flask, request, jsonify
import mysql.connector
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
import jwt
import datetime
import re
import smtplib
import requests
from functools import wraps
import logging
#from werkzeug.security import generate_password_hash, check_password_hash
import hashlib
import scripts.regex as rex
import scripts.mail as mymail 
from revisited import *
from flask_cors import CORS
from google import *

logging.basicConfig(level=logging.DEBUG, format='%(asctime)s - %(levelname)s - %(message)s')

app = Flask(__name__)
CORS(app, resources={r"/*": {"origins": "*"}})

# Configurazione del database MySQL
try:
    db = mysql.connector.connect(
        host="localhost",
        user="root",
        password="",
        database="aziendaDB"
    )
    cursor = db.cursor()
    cursor.execute("SELECT DATABASE();")
    record = cursor.fetchone()
    print("You're connected to database: ", record)
except mysql.connector.Error as err:
    print("Error: ", err)
SECRET_KEY = "bR7g9*!F4hjLwZq@E3#5pU8yS&1xDKfM"  # Scegli una chiave segreta complessa


def create_token(username, company, role):
    expiration = datetime.datetime.utcnow() + datetime.timedelta(days=1)
    try:
        token = jwt.encode({
            'username': username,
            'company': company,
            'role': role,
            'exp': expiration
        }, SECRET_KEY, algorithm='HS256')
        print(f"Token created for {username}: {token}")
        return token
    except Exception as e:
        print(f"Error creating token: {str(e)}")
        return None



def token_required(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        token = None
        if 'Authorization' in request.headers:
            token = request.headers['Authorization'].split(" ")[1]
        if not token:
            return jsonify({'message': 'Token is missing!'}), 401
        try:
            data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
            current_username = data['username']
            print(f"Token decoded for {current_username}: {data}")
        except Exception as e:
            print(f"Token decode error: {str(e)}")
            return jsonify({'message': 'Token is invalid!'}), 401
        return f(current_username, *args, **kwargs)
    return decorated

def google_mail_search(mail):
    cursor = db.cursor()
    try:
        query = "SELECT username FROM user WHERE google_authenticator = %s"
        cursor.execute(query, (mail,))
        user = cursor.fetchone()
        logging.info(f"User from DB: {user}")  # Log the query result
        print(user,type(user))
        user = user[0]
        if user: 
                query_role = "SELECT ruolo, companyName FROM association WHERE username = %s"
                cursor.execute(query_role, (user,))
                role_data = cursor.fetchall()

                roles = [{'username': user, 'role': role[0], 'company': role[1]} for role in role_data]
                is_sa = any(role['role'] == 'SA' for role in roles)

                user_id = user[0]
                token = jwt.encode({
                    'username': user,
                    'user_id': user_id,
                    'roles': roles,
                    'is_sa': is_sa,
                    'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
                }, SECRET_KEY, algorithm="HS256")

                print(f"Login successful for {user}, token: {token}")
                return token
        
    except Exception as e:
        logging.error(f"Error during login: {e}")  # Log the error
        return jsonify({'message': 'Internal server error', 'status': False}), 500
    finally:
        cursor.close()


@app.route("/api/google_log", methods=['POST'])
def google_log():
    token = request.form['id_token']
    try:
        id_info = id_token.verify_oauth2_token(token, google.auth.transport.requests.Request(), GOOGLE_CLIENT_ID)
        email = id_info['email']

        user_token = google_mail_search(email)
        if user_token:
            return jsonify({'message': 'Login successful', 'status': True, 'token': user_token})
        else:
            return jsonify({'message': 'User not found', 'status': False}), 404
    except ValueError:
        return jsonify({'message': 'Invalid token', 'status': False}), 400

def validate_email(email):
    return re.match(r"[^@]+@[^@]+\.[^@]+", email)

def validate_phone_number(phone_number):
    return re.match(r"^\d{10}$", phone_number)

def validate_data(data):
    if not validate_email(data.get('mail', '')):
        return False, "Invalid email format"
    if not validate_phone_number(data.get('phone_number', '')):
        return False, "Invalid phone number format"
    if len(data.get('password', '')) < 6:
        return False, "Password must be at least 6 characters"
    # Add more validation rules as needed
    return True, ""

@app.route('/api/login', methods=['POST'])
def login():
    data = request.json
    logging.info(f"Received data: {data}")  # Log received data
    if not data or 'username' not in data or 'password' not in data:
        return jsonify({'message': 'Missing required parameters'}), 400

    username = data['username']
    password = data['password']

    cursor = db.cursor()
    try:
        query = "SELECT password FROM user WHERE username = %s"
        cursor.execute(query, (username,))
        user = cursor.fetchone()
        #logging.info(f"User from DB: {user}")  # Log the query result

        if user:
            stored_password_hash = user[0]
            provided_password_hash = generate_md5(password)

            if stored_password_hash == provided_password_hash:  # Verify hashed password
                query_role = "SELECT ruolo, companyName FROM association WHERE username = %s"
                cursor.execute(query_role, (username,))
                role_data = cursor.fetchall()

                roles = [{'username': username, 'role': role[0], 'company': role[1]} for role in role_data]
                is_sa = any(role['role'] == 'SA' for role in roles)

                user_id = user[0]
                token = jwt.encode({
                    'username': username,
                    'user_id': user_id,
                    'roles': roles,
                    'is_sa': is_sa,
                    'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
                }, SECRET_KEY, algorithm="HS256")

                print(f"Login successful for {username}, token: {token}")
                return jsonify({'message': 'Login successful', 'status': True, 'token': token})
            else:
                return jsonify({'message': 'Invalid username or password', 'status': False})
        else:
            return jsonify({'message': 'Invalid username or password', 'status': False})
    except Exception as e:
        logging.error(f"Error during login: {e}")  # Log the error
        return jsonify({'message': 'Internal server error', 'status': False}), 500
    finally:
        cursor.close()



@app.route('/api/check_in', methods=['POST'])
@token_required
def check_in(current_username):
    data = request.json
    print("Request Data:", data)  # Aggiungi questo per vedere i dati ricevuti
    username = data.get('username')
    companyName = data.get('companyName')
    room = data.get('room')
    check_in_time = datetime.datetime.now()

    if not username or not companyName or not room:
        return jsonify({'message': 'Missing required parameters'}), 400

    cursor = db.cursor(buffered=True)

    try:
        # Verifica se esiste un record per l'utente e l'azienda nella tabella permission
        query = "SELECT room, check_in FROM permission WHERE username = %s AND companyName = %s"
        cursor.execute(query, (username, companyName))
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
        return jsonify({'message': 'Check-in recorded/updated successfully'}), 200
    except mysql.connector.Error as err:
        db.rollback()
        print(f"Database Error: {err}")
        return jsonify({'message': f'Error: {err}'}), 500
    except Exception as e:
        db.rollback()
        print(f"Unexpected Error: {e}")
        return jsonify({'message': f'Unexpected Error: {e}'}), 500
    finally:
        cursor.close()


@app.route('/api/get_company_users', methods=['GET'])
@token_required
def get_company_users(current_username):
    try:
        current_company = request.args.get('company')
        emulated_username = request.args.get('emulated_username', current_username)
        if not current_company:
            return jsonify({'message': 'Company not provided', 'status': False}), 400

        cursor = db.cursor()
        # Otteniamo il ruolo dell'utente emulato
        cursor.execute("SELECT ruolo FROM association WHERE username = %s AND companyName = %s", (emulated_username, current_company))
        emulated_role = cursor.fetchone()
        if not emulated_role:
            return jsonify({'message': 'User role not found', 'status': False}), 404

        emulated_role = emulated_role[0]
        print(f"Emulated Role: {emulated_role}")

        if emulated_role == 'SA':
            query = "SELECT username, ruolo FROM association WHERE companyName = %s"
        elif emulated_role == 'CA':
            query = "SELECT username, ruolo FROM association WHERE companyName = %s AND ruolo IN ('CO', 'USR')"
        elif emulated_role == 'CO':
            query = "SELECT username, ruolo FROM association WHERE companyName = %s AND ruolo = 'USR'"
        elif emulated_role == 'USR':
            query = "SELECT username, ruolo FROM association WHERE companyName = %s AND username = %s"
            cursor.execute(query, (current_company, emulated_username))
            user = cursor.fetchone()
            result = []
            if user:
                user_dict = {
                    'username': user[0],
                    'role': user[1],
                }
                result.append(user_dict)
            return jsonify({'users': result, 'role': emulated_role}), 200
        else:
            return jsonify({'message': 'Unauthorized', 'status': False}), 403

        cursor.execute(query, (current_company,))
        users = cursor.fetchall()

        result = []
        for user in users:
            user_dict = {
                'username': user[0],
                'role': user[1],
            }
            result.append(user_dict)

        # Log dei dati restituiti
        print(f"Company Users: {result}")

        return jsonify({'users': result, 'role': emulated_role}), 200
    except Exception as e:
        print(f"Error in get_company_users endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500




@app.route('/api/change_company', methods=['POST'])
@token_required
def change_company(current_username):
    data = request.json
    new_company = data.get('company')

    cursor = db.cursor()
    try:
        # Controlla se l'utente è associato a questa azienda
        cursor.execute("SELECT ruolo FROM ASSOCIATION WHERE username = %s AND companyName = %s", (current_username, new_company))
        result = cursor.fetchone()
        if result:
            role = result[0]
            # Crea un nuovo token con la nuova azienda
            new_token = create_token(current_username, new_company, role)
            return jsonify({'token': new_token, 'message': 'Company changed successfully', 'role': role})
        else:
            return jsonify({'message': 'Company not found or not associated with user'}), 404
    finally:
        cursor.close()


@app.route('/api/get_companies', methods=['GET'])
@token_required
def get_companies(current_username):
    cursor = db.cursor()
    try:
        cursor.execute("SELECT companyName, ruolo FROM ASSOCIATION WHERE username = %s", (current_username,))
        results = cursor.fetchall()  # Ottieni tutti i risultati
        companies = [{'name': result[0], 'role': result[1]} for result in results]  # Estrai i nomi e i ruoli delle aziende
    finally:
        cursor.close()
    print(current_username)
    return jsonify({'companies': companies})


@app.route('/api/register', methods=['POST'])
def register():
    data = request.json
    print(data["token"])

    resp, key, suggestion = rex.regex_full_check(data)
    if not resp:
        return jsonify({'message': f'Registration failed: {key}, suggestion: {suggestion}', 'status': False})
    
    is_valid, message = validate_data(data)
    if not is_valid:
        return jsonify({'message': message, 'status': False}), 400

    hashed_password = generate_md5(data['password'])

    cursor = db.cursor()
    try:
        # Check if username already exists
        cursor.execute("SELECT * FROM user WHERE username = %s", (data['username'],))
        existing_user = cursor.fetchone()
        if existing_user:
            return jsonify({'message': 'Username already exists', 'status': False}), 409

        query = """INSERT INTO user (nome, cognome, username, password, fiscal_code, phone_number, mail, address, birth_date, gender, flag_phone, flag_mail, google_authenticator, token) 
                   VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)"""
        cursor.execute(query, (
            data['nome'],
            data['cognome'],
            data['username'],
            hashed_password,
            data['fiscal_code'],
            data['phone_number'],
            data['mail'],
            data['address'],
            data['birth_date'],
            data['gender'],
            data['flag_phone'],
            data['flag_mail'],
            data['google_authenticator'],
            data['token']
        ))
        db.commit()
    finally:
        cursor.close()

    return jsonify({'message': 'Registration successful', 'status': True})


@app.route('/api/get_statistics', methods=['GET'])
@token_required
def get_statistics(current_username):
    try:
        current_company = request.headers.get('Current-Company')
        print(f"Current Company: {current_company}")
        print(f"Current Username (from token): {current_username}")

        if not current_company:
            return jsonify({'message': 'Current company not provided', 'status': False}), 400

        cursor = db.cursor()

        checkin_query = """
            SELECT username, room, check_in
            FROM permission
            WHERE companyName = %s AND username = %s
            ORDER BY check_in
        """
        cursor.execute(checkin_query, (current_company, current_username))
        checkins = cursor.fetchall()
        print(f"Check-ins: {checkins}")

        log_query = """
            SELECT username, room, check_out, time_in_room
            FROM log
            WHERE companyName = %s AND username = %s
            ORDER BY check_out
        """
        cursor.execute(log_query, (current_company, current_username))
        logs = cursor.fetchall()
        print(f"Logs: {logs}")

        statistics = {}

        for checkin in checkins:
            username, room, check_in = checkin
            date_str = check_in.strftime('%Y-%m-%d')
            if date_str not in statistics:
                statistics[date_str] = {
                    'username': username,
                    'rooms': {},
                    'total_checkins': 0,
                    'total_duration': 0,
                    'access_denied': 0
                }
            if room not in statistics[date_str]['rooms']:
                statistics[date_str]['rooms'][room] = {
                    'checkins': 0,
                    'duration': 0
                }
            statistics[date_str]['rooms'][room]['checkins'] += 1
            statistics[date_str]['total_checkins'] += 1

        for log in logs:
            username, room, check_out, time_in_room = log
            date_str = check_out.strftime('%Y-%m-%d')
            if date_str not in statistics:
                statistics[date_str] = {
                    'username': username,
                    'rooms': {},
                    'total_checkins': 0,
                    'total_duration': 0,
                    'access_denied': 0
                }
            if room not in statistics[date_str]['rooms']:
                statistics[date_str]['rooms'][room] = {
                    'checkins': 0,
                    'duration': 0
                }
            try:
                time_parts = time_in_room.split(':')
                duration_seconds = int(time_parts[0]) * 3600 + int(time_parts[1]) * 60 + float(time_parts[2])
                statistics[date_str]['rooms'][room]['duration'] += duration_seconds
                statistics[date_str]['total_duration'] += duration_seconds
            except ValueError:
                print(f"Error parsing time_in_room: {time_in_room}")

        result = []
        for date, data in statistics.items():
            for room, room_data in data['rooms'].items():
                stat_dict = {
                    'username': data['username'],
                    'date': date,
                    'room': room,
                    'checkins': room_data['checkins'],
                    'duration': room_data['duration'],
                }
                result.append(stat_dict)
        print(f"Statistics: {statistics}")
        return jsonify({'statistics': result}), 200
    except Exception as e:
        print(f"Error in get_statistics endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500

@app.route('/api/emulate_user', methods=['POST'])
@token_required
def emulate_user(current_username):
    token = request.headers.get('Authorization')
    print(f"Original token: {token}")
    if not token:
        return jsonify({'message': 'Token is missing!'}), 403

    try:
        token = token.split(" ")[1]  # Remove 'Bearer' prefix
        data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        is_sa = data.get('is_sa')
        print(f"Decoded token data: {data}")
    except Exception as e:
        return jsonify({'message': 'Token is invalid!'}), 403

    emulate_username = request.json.get('username')
    print(f"Emulating user: {emulate_username} by {current_username}")
    current_company = request.json.get('company')

    if not emulate_username:
        return jsonify({'message': 'Username is missing!'}), 400

    cursor = db.cursor()
    try:
        if is_sa:
            query = "SELECT * FROM user WHERE username = %s"
            cursor.execute(query, (emulate_username,))
        else:
            query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
            cursor.execute(query, (current_username, current_company))
            current_role = cursor.fetchone()
            if not current_role:
                return jsonify({'message': 'User role not found', 'status': False}), 404
            
            current_role = current_role[0]
            print(f"Current role: {current_role}")
            if current_role == 'CA':
                query = "SELECT * FROM association WHERE companyName = %s AND username = %s AND ruolo IN ('CO', 'USR')"
            elif current_role == 'CO':
                query = "SELECT * FROM association WHERE companyName = %s AND username = %s AND ruolo = 'USR'"
            else:
                return jsonify({'message': 'Unauthorized', 'status': False}), 403
            
            cursor.execute(query, (current_company, emulate_username))
            user_to_emulate = cursor.fetchone()
            if not user_to_emulate:
                return jsonify({'message': 'Permission denied!', 'status': False}), 403

            query = "SELECT * FROM user WHERE username = %s"
            cursor.execute(query, (emulate_username,))

        user = cursor.fetchone()
        if not user:
            return jsonify({'message': 'User not found!'}), 404

        user_id = user[0]
        new_token = jwt.encode({
            'username': emulate_username,
            'user_id': user_id,
            'exp': datetime.datetime.utcnow() + datetime.timedelta(hours=24)
        }, SECRET_KEY, algorithm="HS256")
        print(f"New token for {emulate_username}: {new_token}")

    except Exception as e:
        print(f"Error in emulate_user endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500

    finally:
        cursor.close()

    return jsonify({'token': new_token})

# Endpoint per la registrazione dell'azienda
@app.route('/api/register_company', methods=['POST'])
@token_required
def register_company(current_username):
    data = request.json

    resp, key, suggestion = rex.regex_full_check(data)
    if not resp:
        return jsonify({'message': f'Registration failed: {key}, suggestion: {suggestion}', 'status': False})

    required_fields = ['companyName', 'VAT_number', 'address', 'phone_number', 'PEC', 'username']
    for field in required_fields:
        if field not in data or not data[field]:
            return jsonify({'error': f'Missing or empty field: {field}'}), 400

    cursor1 = db.cursor(buffered=True)  # Use a buffered cursor
    cursor2 = db.cursor(buffered=True)  # Use a buffered cursor

    try:
        # Check if the company already exists
        cursor1.execute("SELECT COUNT(*) FROM customer WHERE companyName = %s", (data['companyName'],))
        result = cursor1.fetchone()
        print(f"Company name check result: {result}")
        if result and result[0] > 0:
            return jsonify({'error': 'companyName already exists'}), 400

        # Insert the company into the customer table
        insert_query = ("INSERT INTO customer (companyName, VAT_number, address, phone_number, PEC, flag_phone, flag_mail, subscription, country) "
                        "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)")
        cursor1.execute(insert_query, (
            data['companyName'],
            data['VAT_number'],
            data['address'],
            data['phone_number'],
            data['PEC'],
            data.get('flag_phone', ''),
            data.get('flag_mail', ''),
            data.get('subscription', ''),
            data.get('country', '')
        ))
        print("Company inserted into customer table")

        # Ensure there are no unread results by fetching them if any
        while cursor1.nextset():
            pass

        # Determine the role based on the current user's role
        cursor2.execute("SELECT ruolo FROM association WHERE username = %s", (current_username,))
        user_role = cursor2.fetchone()
        print(f"User role: {user_role}")
        if user_role and user_role[0] == 'SA':
            role = 'SA'
        else:
            role = 'CA'

        # Insert the association into the association table
        association_query = "INSERT INTO association (username, companyName, ruolo) VALUES (%s, %s, %s)"
        cursor2.execute(association_query, (data['username'], data['companyName'], role))
        print("Association inserted into association table")

        db.commit()
        return jsonify({'message': 'Registration successful', 'status': True}), 200
    except mysql.connector.Error as e:
        db.rollback()
        print(f"Database error: {e}")
        return jsonify({'error': 'Database error', 'details': str(e)}), 500
    finally:
        cursor1.close()
        cursor2.close()

        

@app.route('/api/change_role', methods=['POST'])
@token_required
def change_role(current_username):
    data = request.json
    username = data.get('username')
    company = data.get('company')
    new_role = data.get('role')

    print(data)

    if not username or not company or not new_role:
        return jsonify({'message': 'Username, company, or role is missing!'}), 400

    cursor = db.cursor()
    try:
        # Verifica se l'utente corrente è SA
        query = "SELECT ruolo FROM association WHERE username = %s AND ruolo = 'SA'"
        cursor.execute(query, (current_username,))
        current_user_role = cursor.fetchone()

        if not current_user_role:
            return jsonify({'message': 'Permission denied! Only SA can change roles!'}), 403

        # Verifica se il record esiste
        select_query = "SELECT * FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(select_query, (username, company))
        record = cursor.fetchone()
        if not record:
            return jsonify({'message': 'User or company not found', 'status': False}), 404

        # Aggiorna il ruolo dell'utente specificato
        update_query = "UPDATE association SET ruolo = %s WHERE username = %s AND companyName = %s"
        cursor.execute(update_query, (new_role, username, company))
        db.commit()

        if cursor.rowcount == 0:
            return jsonify({'message': 'No records updated', 'status': False}), 404

        return jsonify({'message': 'Role updated successfully', 'status': True})
    except Exception as e:
        db.rollback()
        return jsonify({'message': str(e), 'status': False})
    finally:
        cursor.close()


@app.route('/api/change_user_role', methods=['POST'])
@token_required
def change_user_role(current_username):
    data = request.json
    username = data.get('username')
    company = data.get('company')
    new_role = data.get('role')
    print(data)

    if not username or not company or not new_role:
        return jsonify({'message': 'Username, company, or role is missing!'}), 400

    cursor = db.cursor()
    try:
        # Verifica il ruolo corrente dell'utente che richiede il cambio di ruolo
        query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(query, (current_username, company))
        current_user_role = cursor.fetchone()

        if not current_user_role:
            return jsonify({'message': 'Permission denied!'}), 403

        current_user_role = current_user_role[0]

        # Controlla se il ruolo corrente dell'utente permette di cambiare il ruolo
        allowed_roles = {
            'SA': ['SA', 'CA', 'CO', 'USR'],
            'CA': ['CA', 'CO', 'USR'],
            'CO': ['CO', 'USR']
        }

        if current_user_role not in allowed_roles or new_role not in allowed_roles[current_user_role]:
            return jsonify({'message': 'Permission denied!'}), 403

        # Verifica il ruolo dell'utente a cui si desidera cambiare il ruolo
        target_role_query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(target_role_query, (username, company))
        target_user_role = cursor.fetchone()

        if not target_user_role:
            return jsonify({'message': 'Target user not found!'}), 404

        target_user_role = target_user_role[0]

        # Impedisci agli utenti con ruolo CO di cambiare il ruolo di utenti con ruolo CA o SA
        if current_user_role == 'CO' and target_user_role in ['CA', 'SA']:
            return jsonify({'message': 'Permission denied!'}), 403

        # Aggiorna il ruolo dell'utente specificato
        update_query = "UPDATE association SET ruolo = %s WHERE username = %s AND companyName = %s"
        cursor.execute(update_query, (new_role, username, company))
        db.commit()

        return jsonify({'message': 'Role updated successfully', 'status': True})
    except Exception as e:
        db.rollback()
        return jsonify({'message': str(e), 'status': False})
    finally:
        cursor.close()


@app.route('/api/forgot_password', methods=['POST'])
def forgot_password():
    data = request.json
    print(data)
    email = data.get('email')
    if not email:
        return jsonify({'message': 'Email is required'}), 400
    temporary_password = mymail.generate_password()
    temporary_password_hashed = generate_md5(temporary_password)
    print(temporary_password)
    cursor = db.cursor()

    # Verifica se l'email esiste
    cursor.execute("SELECT COUNT(*) FROM user WHERE mail = %s", (email,))
    result = cursor.fetchone()
    if result[0] == 0:
        return jsonify({'message': 'Email not found'}), 404

    # Imposta la password temporanea nel database
    cursor.execute("UPDATE user SET password = %s WHERE mail = %s", (temporary_password_hashed, email))
    db.commit()
    print(temporary_password_hashed)
    print(email)

    # Invia la nuova password temporanea via email
    status_mail, response = mymail.send_mail_pwd(email, temporary_password)
    if status_mail:
        return jsonify({'message': 'Temporary password sent successfully'})
    else:
        return jsonify({'message': response}), 500

@app.route('/api/reset_password', methods=['POST'])
def reset_password():
    data = request.json
    email = data.get('email')
    temporary_password = data.get('temporaryPassword')
    new_password = data.get('newPassword')
    if not email or not temporary_password or not new_password:
        return jsonify({'message': 'Email, temporary password, and new password are required'}), 400
    
    temporary_password_hashed = generate_md5(temporary_password)
    new_password_hashed = generate_md5(new_password)
    
    cursor = db.cursor()

    # Verifica se la password temporanea e l'email sono corrette
    cursor.execute("SELECT COUNT(*) FROM user WHERE mail = %s AND password = %s", (email, temporary_password_hashed))
    result = cursor.fetchone()
    if result[0] == 0:
        return jsonify({'message': 'Invalid email or temporary password'}), 404

    # Aggiorna la password
    cursor.execute("UPDATE user SET password = %s WHERE mail = %s", (new_password_hashed, email))
    db.commit()

    return jsonify({'message': 'Password reset successfully'}), 200


#TODO companyname e fisso, deve dipendere dalla compagnia con la quale si e fatto il login
# @app.route('/api/get_companies', methods=['GET'])
# @token_required
# def get_companies(current_username):
#     #print(current_username)
#     cursor = db.cursor()
#     cursor.execute("SELECT companyName, ruolo FROM ASSOCIATION WHERE userID = %s", (current_username,))
#     results = cursor.fetchall()  # Ottieni tutti i risultati
#     companies = [{'name': result[0], 'role': result[1]} for result in results]  # Estrai i nomi e i ruoli delle aziende
#     return jsonify({'companies': companies})
        

@app.route('/api/update_user', methods=['POST'])
@token_required
def update_user(current_username):
    data = request.json
    logging.info(f"Received data for update: {data}")
    
    cursor = db.cursor()

    # Usa il username nel corpo della richiesta se presente, altrimenti usa current_username
    username_to_update = data.get('username', current_username)
    print(username_to_update)

    # Rimuovi la validazione della password che non è necessaria qui
    is_valid, message = validate_data2(data, validate_password=False)
    if not is_valid:
        return jsonify({'message': message, 'status': False}), 400

    update_statement = """
    UPDATE user SET
        nome = %s,
        cognome = %s,
        fiscal_code = %s,
        phone_number = %s,
        mail = %s,
        address = %s,
        birth_date = %s,
        gender = %s,
        flag_phone = %s,
        flag_mail = %s,
        google_authenticator = %s,
        token = %s
    WHERE username = %s
    """
    try:
        cursor.execute(update_statement, (
            data['nome'],
            data['cognome'],
            data['fiscal_code'],
            data['phone_number'],
            data['mail'],
            data['address'],
            data['birth_date'],
            data['gender'],
            data['flag_phone'],
            data['flag_mail'],
            data['google_authenticator'],
            data['token'],
            username_to_update
        ))
        db.commit()
        return jsonify({'message': 'Profile updated successfully', 'status': True})
    except Exception as e:
        db.rollback()
        logging.error(f"Error updating profile: {e}")
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()

def validate_data2(data, validate_password=True):
    if not validate_email(data.get('mail', '')):
        return False, "Invalid email format"
    if not validate_phone_number(data.get('phone_number', '')):
        return False, "Invalid phone number format"
    if validate_password and len(data.get('password', '')) < 6:
        return False, "Password must be at least 6 characters"
    # Add more validation rules as needed
    return True, ""


@app.route('/api/change_password', methods=['POST'])
@token_required
def change_password(current_username):
    data = request.get_json()
    old_password = data.get('old_password')
    new_password = data.get('new_password')
    
    if not old_password or not new_password:
        return jsonify({'status': False, 'message': 'Missing required parameters'}), 400

    cursor = db.cursor(dictionary=True)
    
    # Fetch the current password hash from the database
    cursor.execute("SELECT password FROM user WHERE username = %s", (current_username,))
    result = cursor.fetchone()
    
    if not result:
        return jsonify({'status': False, 'message': 'User not found'}), 404
    
    stored_password_hash = result['password']
    old_password_hash = generate_md5(old_password)
    
    if stored_password_hash != old_password_hash:
        return jsonify({'status': False, 'message': 'Old password is incorrect'}), 400
    
    new_password_hash = generate_md5(new_password)
    
    cursor.execute("UPDATE user SET password = %s WHERE username = %s", (new_password_hash, current_username))
    db.commit()
    
    return jsonify({'status': True, 'message': 'Password changed successfully'})


@app.route('/api/get_details', methods=['GET'])
@token_required
def get_details(current_username):
    print(f"Current username: {current_username}")
    cursor = db.cursor()
    try:
        cursor.execute("SELECT nome, cognome, fiscal_code, phone_number, mail, address, birth_date, gender, flag_phone, flag_mail, google_authenticator, token FROM user WHERE username = %s", (current_username,))
        user = cursor.fetchone()
        print(f"User details from DB: {user}")
        if user:
            user_details = {
                'nome': user[0],
                'cognome': user[1],
                'fiscal_code': user[2],
                'phone_number': user[3],
                'mail': user[4],
                'address': user[5],
                'birth_date': user[6],
                'gender': user[7],
                'token': user[11]
            }
            return jsonify({'user_details': user_details, 'status': True})
        else:
            return jsonify({'message': 'User not found', 'status': False}), 404
    except Exception as e:
        print(f"Error fetching user details: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()






@app.route('/api/enroll_user', methods=['POST'])
@token_required
def enroll_user(current_username):
    data = request.json
    username = data.get('username')
    role = data.get('role')
    company_name = data.get('companyName')

    print(data)

    if not username or not role or not company_name:
        return jsonify({'message': 'Username, role, and company name are required!'}), 400

    cursor = db.cursor()
    try:
        # Verifica il ruolo corrente dell'utente che richiede l'iscrizione
        query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(query, (current_username, company_name))
        current_user_role = cursor.fetchone()

        if current_user_role == None:
            current_user_role = data.get('current_user_role')

        print(data.get('current_user_role'))

        if not current_user_role:
            return jsonify({'message': 'Permission denied!'}), 403

        current_user_role = current_user_role[0]

        allowed_roles = {
            'SA': ['SA', 'CA', 'CO', 'USR'],
            'CA': ['CA', 'CO', 'USR'],
            'CO': ['CO', 'USR']
        }

        # if current_user_role not in allowed_roles or role not in allowed_roles[current_user_role]:
        #     return jsonify({'message': 'Permission denied!'}), 403

        query = "INSERT INTO association (username, companyName, ruolo) VALUES (%s, %s, %s)"
        cursor.execute(query, (username, company_name, role))
        db.commit()
        return jsonify({'message': 'User enrolled successfully', 'status': True}), 200
    except Exception as e:
        db.rollback()
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()



@app.route('/api/remove_user', methods=['POST'])
def remove_user():
    if not request.json or 'username' not in request.json:
        return jsonify({'error': 'Bad Request', 'message': 'Username is required'}), 400

    username = request.json['username']
    cursor = db.cursor()

    try:
        # Delete user from association table
        cursor.execute('DELETE FROM association WHERE username = %s', (username,))

        # Delete user from user table
        cursor.execute('DELETE FROM user WHERE username = %s', (username,))

        db.commit()
        message = f'User {username} has been removed'
        success = True
    except mysql.connector.Error as err:
        db.rollback()
        message = f'Error: {err}'
        success = False
    finally:
        cursor.close()

    return jsonify({'success': success, 'message': message}), 200 if success else 500

@app.route('/api/remove_company', methods=['POST'])
def remove_company():
    if not request.json or 'companyName' not in request.json:
        return jsonify({'error': 'Bad Request', 'message': 'companyName is required'}), 400

    companyName = request.json['companyName']
    cursor = db.cursor()

    try:
        # Delete user from association table
        cursor.execute('DELETE FROM association WHERE companyName = %s', (companyName,))

        # Delete user from user table
        cursor.execute('DELETE FROM customer WHERE companyName = %s', (companyName,))

        db.commit()
        message = f'company {companyName} has been removed'
        success = True
    except mysql.connector.Error as err:
        db.rollback()
        message = f'Error: {err}'
        success = False
    finally:
        cursor.close()

    return jsonify({'success': success, 'message': message}), 200 if success else 500

@app.route('/api/remove_user_company', methods=['POST'])
@token_required
def remove_user_company(current_username):
    data = request.json
    username_to_remove = data.get('username')
    company_name = data.get('companyName')

    if not username_to_remove or not company_name:
        return jsonify({'message': 'Username and company name are required!'}), 400

    cursor = db.cursor()
    try:
        # Verifica il ruolo dell'utente corrente
        query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(query, (current_username, company_name))
        current_user_role = cursor.fetchone()

        if not current_user_role:
            return jsonify({'message': 'Permission denied!'}), 403

        current_user_role = current_user_role[0]

        # Definisce le condizioni per la rimozione in base al ruolo corrente dell'utente
        if current_user_role == 'SA':
            query = "DELETE FROM association WHERE username = %s AND companyName = %s"
            cursor.execute(query, (username_to_remove, company_name))
        elif current_user_role == 'CA':
            query = "DELETE FROM association WHERE username = %s AND companyName = %s AND ruolo IN ('CA', 'CO', 'USR')"
            cursor.execute(query, (username_to_remove, company_name))
        elif current_user_role == 'CO':
            query = "DELETE FROM association WHERE username = %s AND companyName = %s AND ruolo IN ('CO', 'USR')"
            cursor.execute(query, (username_to_remove, company_name))
        else:
            return jsonify({'message': 'Permission denied!'}), 403

        db.commit()
        return jsonify({'message': 'User removed successfully', 'status': True}), 200
    except Exception as e:
        db.rollback()
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()



@app.route('/api/get_all_users', methods=['GET'])
@token_required
def get_all_users(current_username):
    cursor1 = db.cursor()
    try:
        cursor1.execute("SELECT ruolo FROM association WHERE username = %s AND ruolo = 'SA'", (current_username,))
        current_user_role = cursor1.fetchone()
        
        if not current_user_role:
            return jsonify({'message': 'Permission denied! Only SA can view the user list!'}), 403

    except Exception as e:
        print(f"Error checking user role: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    
    finally:
        try:
            cursor1.fetchall()
        except mysql.connector.errors.InterfaceError:
            pass
        cursor1.close()

    cursor2 = db.cursor()
    try:
        cursor2.execute("SELECT username FROM user")
        users = cursor2.fetchall()
        usernames = [user[0] for user in users]
        return jsonify({'usernames': usernames}), 200

    except Exception as e:
        print(f"Error in get_all_users endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    
    finally:
        try:
            cursor2.fetchall()
        except mysql.connector.errors.InterfaceError:
            pass
        cursor2.close()


@app.route('/api/get_users', methods=['GET'])
@token_required
def get_users(current_username):
    token = request.headers.get('Authorization')
    if not token:
        return jsonify({'message': 'Token is missing!'}), 403
    
    try:
        token = token.split(" ")[1]  # Remove 'Bearer' prefix
        data = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        if not data.get('is_sa'):
            return jsonify({'message': 'Permission denied!'}), 403
    except Exception as e:
        return jsonify({'message': 'Token is invalid!'}), 403

    cursor = db.cursor()
    try:
        query = """
        SELECT DISTINCT u.username 
        FROM user u
        LEFT JOIN association a ON u.username = a.username
        WHERE a.ruolo != 'SA' OR a.ruolo IS NULL
    """
        cursor.execute(query)
        users = cursor.fetchall()
        usernames = [user[0] for user in users]
    finally:
        cursor.close()

    return jsonify({'usernames': usernames})

@app.route('/api/get_user_details', methods=['GET'])
@token_required
def get_user_details(current_username):
    token = request.headers.get('Authorization')
    print(f"Received token: {token} for getting user details")
    
    username = request.args.get('username')
    if not username:
        return jsonify({'message': 'Username not provided'}), 400

    print(f"Getting details for user: {username}")
    
    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM user WHERE username = %s", (username,))
        user = cursor.fetchone()
        if not user:
            return jsonify({'message': 'User not found!'}), 404

        user_details = {
            #'userID': user[0],
            'nome': user[1],
            'cognome': user[2],
            'username': user[3],
            #'password': user[4],
            'fiscal_code': user[5],
            'phone_number': user[6],
            'mail': user[7],
            'address': user[8],
            'birth_date': user[9],
            'gender': user[10],
            #'flag_phone': user[11],
            #'flag_mail': user[12],
            #'google_authenticator': user[13],
            'token': user[14]
        }
        print(f"User details: {user_details}")
        return jsonify({'user_details': user_details}), 200
    except Exception as e:
        print(f"Error in get_user_details endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()


@app.route('/api/get_all_companies', methods=['GET'])
@token_required
def get_all_companies(current_username):
    cursor1 = db.cursor()
    try:
        cursor1.execute("SELECT ruolo FROM association WHERE username = %s AND ruolo = 'SA'", (current_username,))
        current_user_role = cursor1.fetchone()

        if not current_user_role:
            return jsonify({'message': 'Permission denied! Only SA can view the company list!'}), 403

    except Exception as e:
        print(f"Error checking user role: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    
    finally:
        try:
            cursor1.fetchall()
        except mysql.connector.errors.InterfaceError:
            pass
        cursor1.close()

    cursor2 = db.cursor()
    try:
        cursor2.execute("SELECT companyName FROM customer")
        companies = cursor2.fetchall()

        company_names = [company[0] for company in companies]
        return jsonify({'company_names': company_names}), 200

    except Exception as e:
        print(f"Error fetching companies: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    
    finally:
        try:
            cursor2.fetchall()
        except mysql.connector.errors.InterfaceError:
            pass
        cursor2.close()




@app.route('/api/get_company_details', methods=['GET'])
@token_required
def get_company_details(current_username):
    company_name = request.args.get('companyName')
    if not company_name:
        return jsonify({'message': 'Company name not provided'}), 400

    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM customer WHERE companyName = %s", (company_name,))
        company = cursor.fetchone()
        if not company:
            return jsonify({'message': 'Company not found!'}), 404

        company_details = {
            'companyName': company[1],
            'VAT_number': company[2],
            'address': company[3],
            'phone_number': company[4],
            'PEC': company[5],
            #'flag_phone': company[6],
            #'flag_mail': company[7],
            'subscription': company[8],
            'country': company[9]
        }
        return jsonify({'company_details': company_details}), 200
    except Exception as e:
        print(f"Error in get_company_details endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()

@app.route('/api/add_room', methods=['POST'])
@token_required
def add_room(current_username):
    data = request.json
    room_name = data.get('roomName')
    allowed_denied = data.get('allowedDenied')
    company_name = data.get('companyName')

    if not room_name or allowed_denied is None:
        return jsonify({'message': 'Room name and allowed/denied status are required!'}), 400

    cursor = db.cursor()
    try:
        # Verifica se l'utente corrente è CA per la compagnia specificata
        query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(query, (current_username, company_name))
        current_user_role = cursor.fetchone()

        if not current_user_role or current_user_role[0] != 'CA':
            return jsonify({'message': 'Permission denied! Only CA can add rooms!'}), 403

        # Inserisci la nuova stanza nella tabella rooms
        query = "INSERT INTO rooms (companyName, roomName, username, allowed_denied) VALUES (%s, %s, 'ALL', %s)"
        cursor.execute(query, (company_name, room_name, allowed_denied))
        db.commit()

        return jsonify({'message': 'Room added successfully', 'status': True}), 200
    except Exception as e:
        db.rollback()
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()

# Aggiungi questo endpoint nel file server Flask

@app.route('/api/permission_rights', methods=['POST'])
@token_required
def permission_rights(current_username):
    data = request.json
    room_name = data.get('roomName')
    username = data.get('username')
    allowed_denied = data.get('allowedDenied')
    company_name = data.get('companyName')

    if not room_name or not username or allowed_denied is None:
        return jsonify({'message': 'Missing required parameters'}), 400

    cursor = db.cursor()
    try:
        # Check role of current user
        query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(query, (current_username, company_name))
        current_user_role = cursor.fetchone()
        if not current_user_role:
            return jsonify({'message': 'Permission denied!'}), 403

        current_user_role = current_user_role[0]

        # CO role validation
        if current_user_role == 'CO':
            query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
            cursor.execute(query, (username, company_name))
            user_role = cursor.fetchone()
            if not user_role or user_role[0] not in ('USR', 'CO'):
                return jsonify({'message': 'Permission denied!'}), 403

        allowed_denied_str = 'allowed' if allowed_denied else 'denied'
        allowed_denied_value = True if allowed_denied == 'allowed' else False

        query = """
            INSERT INTO rooms (companyName, roomName, username, allowed_denied)
            VALUES (%s, %s, %s, %s)
            ON DUPLICATE KEY UPDATE
                allowed_denied = VALUES(allowed_denied)
        """
        cursor.execute(query, (company_name, room_name, username, allowed_denied_value))
        db.commit()

        return jsonify({'message': 'Permission rights updated successfully'}), 200
    except mysql.connector.Error as err:
        db.rollback()
        return jsonify({'message': f'Error: {err}'}), 500
    finally:
        cursor.close()


@app.route('/api/remove_room', methods=['POST'])
@token_required
def remove_room(current_username):
    data = request.json
    room_name = data.get('roomName')
    company_name = data.get('companyName')

    if not room_name or not company_name:
        return jsonify({'message': 'Room name and company name are required!'}), 400

    cursor = db.cursor()
    try:
        # Verifica se l'utente corrente è CA per la compagnia specificata
        query = "SELECT ruolo FROM association WHERE username = %s AND companyName = %s"
        cursor.execute(query, (current_username, company_name))
        current_user_role = cursor.fetchone()

        if not current_user_role or current_user_role[0] != 'CA':
            return jsonify({'message': 'Permission denied! Only CA can remove rooms!'}), 403

        # Rimuovi la stanza dalla tabella rooms
        delete_query = "DELETE FROM rooms WHERE companyName = %s AND roomName = %s"
        cursor.execute(delete_query, (company_name, room_name))
        db.commit()

        return jsonify({'message': 'Room removed successfully', 'status': True}), 200
    except Exception as e:
        db.rollback()
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()

@app.route('/api/get_rooms', methods=['GET'])
@token_required
def get_rooms(current_username):
    current_company = request.headers.get('Current-Company')
    
    if not current_company:
        return jsonify({'message': 'Current company not provided', 'status': False}), 400

    cursor = db.cursor()
    try:
        query = "SELECT DISTINCT roomName FROM rooms WHERE companyName = %s"
        cursor.execute(query, (current_company,))
        rooms = cursor.fetchall()

        room_names = [room[0] for room in rooms]
        print(f"Fetched rooms for company {current_company}: {room_names}")

        return jsonify({'rooms': room_names}), 200
    except Exception as e:
        print(f"Error in get_rooms endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()

@app.route('/api/check_room_access', methods=['POST'])
@token_required
def check_room_access(current_username):
    data = request.json
    room_name = data.get('roomName')
    company_name = data.get('companyName')
    user_role = data.get('role')

    if not room_name or not company_name or not user_role or not current_username:
        return jsonify({'message': 'Missing required parameters'}), 400

    cursor = db.cursor()
    try:
        # Controllo se l'utente ha un record specifico nella stanza
        query = """
            SELECT allowed_denied FROM rooms 
            WHERE companyName = %s AND roomName = %s AND username = %s
        """
        cursor.execute(query, (company_name, room_name, current_username))
        result = cursor.fetchone()

        if result:
            allowed_denied = result[0]
            if allowed_denied:
                return jsonify({'message': 'Access granted'}), 200
            else:
                return jsonify({'message': 'Access denied'}), 403
        else:
            # Controllo se c'è un ruolo associato alla stanza
            query = """
                SELECT allowed_denied, username FROM rooms 
                WHERE companyName = %s AND roomName = %s AND username IN ('ALL', %s, 'USR', 'CO', 'CA', 'SA')
            """
            cursor.execute(query, (company_name, room_name, user_role))
            result = cursor.fetchall()

            if result:
                access_granted = False
                for row in result:
                    allowed_denied = row[0]
                    role_in_db = row[1]
                    if role_in_db == 'ALL' and allowed_denied:
                        access_granted = True
                    if role_in_db == 'USR' and allowed_denied:
                        if user_role in ['USR', 'CO', 'CA', 'SA']:
                            access_granted = True
                    if role_in_db == 'CO' and allowed_denied:
                        if user_role in ['CO', 'CA', 'SA']:
                            access_granted = True
                    if role_in_db == 'CA' and allowed_denied:
                        if user_role in ['CA', 'SA']:
                            access_granted = True

                if access_granted:
                    return jsonify({'message': 'Access granted'}), 200
                else:
                    return jsonify({'message': 'Access denied'}), 403
            else:
                return jsonify({'message': 'Access denied'}), 403
    except mysql.connector.Error as err:
        print(f"Database Error: {err}")
        return jsonify({'message': f'Error: {err}'}), 500
    except Exception as e:
        print(f"Unexpected Error: {e}")
        return jsonify({'message': f'Unexpected Error: {e}'}), 500
    finally:
        cursor.close()


@app.route('/api/rpi_token', methods=['POST'])
def get_data():
    rfid_token = request.json.get('rfid_token')
    rfid_company = request.json.get('company_name')
    rfid_room = request.json.get('room')

    logging.debug(f"Received - RFID Token: {rfid_token}, Company: {rfid_company}, Room: {rfid_room}")

    if not rfid_token or not rfid_company or not rfid_room:
        return jsonify({'message': 'Missing required parameters', 'status': False, "color": "white"}), 200

    cursor = db.cursor()
    try:
        # Prima query per ottenere l'username basato sul token
        query_user = "SELECT username FROM user WHERE token = %s"
        cursor.execute(query_user, (rfid_token,))
        username = cursor.fetchone()
        if username is None:
            return jsonify({'message': f'User not found, token : {rfid_token}', 'status': False, "color": "orange"}), 200

        username = username[0]
        logging.debug(f"Username found: {username}")

        payload_role = {"username": username, "companyName": rfid_company}
        response_role = requests.post('http://localhost:5000/api/get_role', json=payload_role)
        logging.debug(f"Role API response status: {response_role.status_code}")
        logging.debug(f"Role API response body: {response_role.text}")

        if response_role.status_code != 200:
            return jsonify({'message': 'Failed to get role', 'status': False, "color": "white"}), response_role.status_code

        role = response_role.json().get('role')
        logging.debug(f"Role got: {role}")

        # Controllo preliminare del ruolo per l'accesso alla stanza
        payload_check_access = {
            "roomName": rfid_room,
            "companyName": rfid_company,
            "role": role
        }
        headers = {'Authorization': f'Bearer {create_token(username, rfid_company, role)}'}
        response_check_access = requests.post('http://localhost:5000/api/check_room_access', json=payload_check_access, headers=headers)
        logging.debug(f"Access API response status: {response_check_access.status_code}")
        logging.debug(f"Access API response body: {response_check_access.text}")

        if response_check_access.status_code != 200:
            logging.debug("User not allowed to access the room")
            return jsonify({'message': 'User not allowed', 'status': False, "color": "red", "username": username}), 200

        logging.debug("User allowed to access the room")

        # Seconda query per ottenere la stanza e la compagnia attuale
        checkin_query = """
            SELECT username, room, companyName
            FROM permission
            WHERE username = %s 
            ORDER BY check_in DESC
            LIMIT 1
        """
        logging.debug(f"Executing query: {checkin_query} with username: {username}")
        cursor.execute(checkin_query, [username])
        checkin = cursor.fetchone()

        if checkin is None:
            logging.error(f"Check-in data not found for user: {username}")
            token = create_token(username, rfid_company, role)
            headers = {'Authorization': f'Bearer {token}'}
            print(headers)
            payload_check_in = {"username": username, "companyName": rfid_company, "room": "hall"}
            response_check_in = requests.post('http://127.0.0.1:5000/api/check_in', json=payload_check_in, headers=headers)
            actual_company = rfid_company
            actual_room = "hall"
            # return jsonify({'message': 'Check-in data not found', 'status': False, "color": "gray"}), 200
        else:
            actual_company = checkin[2]
            actual_room = checkin[1]
        logging.debug(f"Check-in found - Username: {username}, Room: {actual_room}, Company: {actual_company}")

    except Exception as e:
        logging.error(f"An error occurred: {e}")
        return jsonify({'message': 'Internal server error', 'status': False, "color": "white"}), 200
    finally:
        cursor.close()

    try:
        print(username, rfid_company, role)
        token = create_token(username, rfid_company, role)
        headers = {'Authorization': f'Bearer {token}'}
        print(headers)
        print(rfid_room)
        print(actual_room)
        if rfid_company == actual_company and rfid_room == actual_room:
            print("no_room")
            temp_room = "hall"
            payload_check_in = {"username": username, "companyName": rfid_company, "room": "hall"}
            response_check_in = requests.post('http://127.0.0.1:5000/api/check_in', json=payload_check_in, headers=headers)
            response_check_in.raise_for_status()
            return jsonify({'message': f'Check-in successful in {temp_room}' , 'username': username, 'status': True, "color": "green"}), response_check_in.status_code
        else:
            print("yes_room")
            temp_room = f"{rfid_room}"
            payload_check_in = {"username": username, "companyName": rfid_company, "room": rfid_room}
            response_check_in = requests.post('http://127.0.0.1:5000/api/check_in', json=payload_check_in, headers=headers)
            response_check_in.raise_for_status()
            return jsonify({'message': f'Check-in successful in {temp_room} with token {rfid_token}', 'username': username, 'status': True, "color": "green"}), response_check_in.status_code
        #print(temp_room)
        #response_check_in = requests.post('http://127.0.0.1:5000/api/check_in', json=payload_check_in, headers=headers)
        #response_check_in.raise_for_status()
        #return jsonify({'message': f'Check-in successful in {temp_room}', 'username': username, 'status': True, "color": "green"}), response_check_in.status_code
    except requests.exceptions.HTTPError as http_err:
        logging.error(f"HTTP error occurred: {http_err}")
        return jsonify({'message': f'HTTP error occurred: {http_err}', 'status': False, "color": "white"}), 400
    except Exception as err:
        logging.error(f"Other error occurred: {err}")
        return jsonify({'message': f'Other error occurred: {err}', 'status': False, "color": "white"}), 400

@app.route('/api/get_role', methods=['POST'])
def get_role():
    data = request.json
    username = data.get("username")
    companyName = data.get("companyName")
    
    if not username or not companyName:
        return jsonify({'message': 'missing parameters'}), 400

    cursor = db.cursor()
    try:
        logging.debug(f"Executing query with username: {username} and companyName: {companyName}")
        cursor.execute("""SELECT ruolo FROM association WHERE username = %s AND companyName = %s""",
                        (username, companyName))
        result = cursor.fetchone()
        
        if result:
            role = result[0]
            return jsonify({'role': role}), 200
        else:
            return jsonify({'message': 'user or company not found'}), 404

    except mysql.connector.Error as err:
        logging.error(f"Database error: {err}")
        return jsonify({'message': f'Error: {err}'}), 500

    finally:
      cursor.close()


@app.route('/api/get_company_details_CA', methods=['GET'])
@token_required
def get_company_details_CA(current_username):
    company_name = request.args.get('companyName')
    if not company_name:
        return jsonify({'message': 'Company name not provided'}), 400

    try:
        cursor = db.cursor()
        cursor.execute("SELECT * FROM customer WHERE companyName = %s", (company_name,))
        company = cursor.fetchone()
        if not company:
            return jsonify({'message': 'Company not found!'}), 404

        company_details = {
            'companyName': company[1],
            'VAT_number': company[2],
            'address': company[3],
            'phone_number': company[4],
            'PEC': company[5],
            'flag_phone': company[6],
            'flag_mail': company[7],
            'subscription': company[8],
            'country': company[9]
        }
        return jsonify({'company_details': company_details}), 200
    except Exception as e:
        print(f"Error in get_company_details endpoint: {str(e)}")
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()


@app.route('/api/company_sizes', methods=['GET'])
@token_required
def get_company_sizes(current_username):
    try:
        print("CIAO")
        cursor = db.cursor()
        query = """
            SELECT companyName, COUNT(username) as user_count
            FROM association
            GROUP BY companyName
        """
        cursor.execute(query)
        
        # Verifica se ci sono risultati prima di tentare di recuperare i dati
        if cursor.rowcount == 0:
            return jsonify({
                'large_companies': 0,
                'medium_companies': 0,
                'small_companies': 0
            }), 200
        
        results = cursor.fetchall()
        print(f"Query results: {results}")  # Log dei risultati della query
        
        large_companies = 0
        medium_companies = 0
        small_companies = 0

        for result in results:
            user_count = result[1]
            if user_count > 10:
                large_companies += 1
                medium_companies -= 1
                small_companies -= 1
            elif 5 <= user_count <= 10:
                medium_companies += 1
                small_companies -= 1
            else:
                small_companies += 1

        print(large_companies, medium_companies, small_companies)

        return jsonify({
            'large_companies': large_companies,
            'medium_companies': medium_companies,
            'small_companies': small_companies
        }), 200
    except Exception as e:
        print(f"Error occurred: {e}")  # Log dettagliato dell'errore
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()











# TODO fix
# @app.route('/api/delete_customer', methods=['GET'])
# @token_required
# def delete_customer(current_username, customer ):
#     print(current_username, customer)
#     cursor = db.cursor()
#     query = f"DELETE FROM {tabella} WHERE customer = %s"
#     cursor.execute(query, (customer,))
#     db.commit()
#     return jsonify({'message': 'DELETE customer successful', 'status': True})

# @app.route('/api/delete_user', methods=['GET'])
# @token_required
# def delete_customer(current_username, user ):
#     print(current_username, user)
#     cursor = db.cursor()
#     query = f"DELETE FROM {tabella} WHERE user = %s"
#     cursor.execute(query, (user,))
#     db.commit()
#     return jsonify({'message': 'DELETE user successful', 'status': True})

# @app.route('/api/edit_role', methods=['GET'])
# @token_required_advanced
# def edit_role(data):
    
#     # la richiesta dovrebbe contenere, a chi cambiareruolo e il ruolo richiesto
#     # 
#     request_ = request.json
#     print(request_)
    
    
#     current_username = data["current_username"]
#     user_id = data["user_id"]
#     print(data)
    
#     cursor = db.cursor()
#     cursor.execute("SELECT companyName, ruolo FROM ASSOCIATION WHERE userID = %s", (current_username,))
#     results = cursor.fetchall()  # Ottieni tutti i risultati
#     companies = [{'name': result[0], 'role': result[1]} for result in results]  # Estrai i nomi e i ruoli delle aziende
#     return jsonify({'companies': companies})
        
def generate_md5(input_string):
    # Create an md5 hash object
    md5_hash = hashlib.md5()
    
    # Update the hash object with the bytes of the input string
    md5_hash.update(input_string.encode('utf-8'))
    
    # Get the hexadecimal representation of the hash
    return md5_hash.hexdigest()


if __name__ == '__main__':
    #app.run(debug=True)
    app.run(debug=True, host='0.0.0.0', port=5000) 






""" @app.route('/api/logout', methods=['POST'])
def logout():
    data = request.json
    token = data.get('token')

    # Verifica del token e decodifica per ottenere lo username
    try:
        decoded_token = jwt.decode(token, SECRET_KEY, algorithms=["HS256"])
        username = decoded_token['username']
        original_username = decoded_token.get('original_username', username)
    except jwt.ExpiredSignatureError:
        return jsonify({'message': 'Token expired', 'status': False}), 401
    except jwt.InvalidTokenError:
        return jsonify({'message': 'Invalid token', 'status': False}), 401

    cursor = db.cursor()
    try:
        query = "SELECT access_date, clock_in, clock_out FROM usage_statistics WHERE username = %s ORDER BY access_date DESC LIMIT 1"
        cursor.execute(query, (original_username,))
        access_record = cursor.fetchone()

        if access_record:
            access_date, clock_in, clock_out = access_record

            # Estrai l'ora da clock_in
            clock_in_time = datetime.datetime.min + clock_in
            session_start_time = datetime.datetime.combine(access_date, clock_in_time.time())

            clock_out_time = datetime.datetime.now()
            total_duration = clock_out_time - session_start_time
            total_duration_str = str(total_duration)

            update_query = "UPDATE usage_statistics SET clock_out = %s, total_duration = %s WHERE username = %s AND clock_out IS NULL"
            cursor.execute(update_query, (datetime.datetime.now().strftime('%H:%M:%S'), total_duration_str, original_username))
            db.commit()
        else:
            return jsonify({'message': 'No access record found', 'status': False}), 404
    except Exception as e:
        db.rollback()
        return jsonify({'message': str(e), 'status': False}), 500
    finally:
        cursor.close()

    return jsonify({'message': 'Logout successful', 'status': True, 'original_username': original_username}), 200
 """



""" @app.route('/api/log_access', methods=['POST'])
@token_required
def log_access(current_username):
    data = request.json

    if 'company' not in data:
        return jsonify({'message': 'Company not provided', 'status': False}), 400

    try:
        current_time = datetime.datetime.now().strftime('%H:%M:%S')
        current_date = datetime.datetime.now().strftime('%Y-%m-%d')

        cursor = db.cursor()
        query = "INSERT INTO usage_statistics (username, access_date, clock_in, companyName) VALUES (%s, %s, %s, %s)"
        
        # Aggiungiamo log per i dati di input
        print(f"Logging access for user: {current_username}, date: {current_date}, time: {current_time}, company: {data.get('company')}")

        cursor.execute(query, (current_username, current_date, current_time, data.get('company')))
        db.commit()

        return jsonify({'message': 'Access logged successfully', 'status': True}), 200

    except mysql.connector.Error as err:
        print("Error logging access:", err)
        db.rollback()
        return jsonify({'message': 'Error logging access', 'status': False}), 500

    finally:
        cursor.close() """