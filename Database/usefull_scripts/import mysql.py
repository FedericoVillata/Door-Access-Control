import mysql.connector
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="",
    database="aziendadb"
)

# CREARE TABELLE 

cursor = db.cursor()
cursor.execute("CREATE TABLE ASSOCIATION (username VARCHAR(30), companyName VARCHAR(30), ruolo VARCHAR(30))")
cursor.execute("CREATE TABLE USER (userID INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(30), cognome VARCHAR(30), username VARCHAR(30), password VARCHAR(30), fiscal_code VARCHAR(30), phone_number INT(20), mail VARCHAR(30), address VARCHAR(50), birth_date VARCHAR(20), gender CHAR, flag_phone CHAR, flag_mail CHAR, google_authenticator VARCHAR(30))")
cursor.execute("CREATE TABLE CUSTOMER (customerID INT AUTO_INCREMENT PRIMARY KEY, nome VARCHAR(30), VAT_number VARCHAR(30), address VARCHAR(30), phone_number VARCHAR(30), PEC VARCHAR(30), flag_phone CHAR, flag_mail CHAR, subscription CHAR, country VARCHAR(30))")
cursor.execute("CREATE TABLE USER_TO_CUSTOMER (code INT AUTO_INCREMENT PRIMARY KEY, cusID VARCHAR(30), userID VARCHAR(30), ruolo VARCHAR(20), time_in VARCHAR(20), time_out VARCHAR(20))")
cursor.execute("CREATE TABLE ACCESS_TABLE (code INT AUTO_INCREMENT PRIMARY KEY, cusID VARCHAR(30), userID VARCHAR(30), department VARCHAR(30), start_date DATE, finish_date DATE, token_1 INT(50), token_2 INT(50), PIN INT(6))")
cursor.execute("CREATE TABLE ACCESS_ADMINISTRATION (code INT AUTO_INCREMENT PRIMARY KEY, cusID VARCHAR(30), userID VARCHAR(30), department VARCHAR(30), ruolo VARCHAR(20))")
cursor.execute("CREATE TABLE REGEX (ID VARCHAR(30) PRIMARY KEY, format VARCHAR(30), flag_format CHAR)")
cursor.execute("CREATE TABLE DAC_RULES (code INT AUTO_INCREMENT PRIMARY KEY, RPI VARCHAR(30), cusID VARCHAR(30), roles VARCHAR(20), wl VARCHAR(30), bl VARCHAR(30))")


