from werkzeug.security import generate_password_hash
import mysql.connector

# Connessione al database MySQL
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="",
    database="aziendaDB"
)

cursor = db.cursor()

# Seleziona tutte le password in chiaro
select_query = "SELECT username, password FROM user"
cursor.execute(select_query)
users = cursor.fetchall()

# Aggiorna ogni password con la versione hashata
for user in users:
    username = user[0]
    plain_password = user[1]
    hashed_password = generate_password_hash(plain_password, method='scrypt')

    # Aggiorna la password nel database
    update_query = "UPDATE user SET password = %s WHERE username = %s"
    cursor.execute(update_query, (hashed_password, username))
    db.commit()

cursor.close()
db.close()

print("Tutte le password sono state aggiornate con successo.")
