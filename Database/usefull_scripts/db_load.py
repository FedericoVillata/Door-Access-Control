import subprocess

def import_mysql_database(username, password, database_name, input_file):
    """
    Importa un database MySQL utilizzando il comando mysql.
    
    :param username: Nome utente del database MySQL
    :param password: Password del database MySQL
    :param database_name: Nome del database in cui importare i dati
    :param input_file: Percorso del file di input contenente il dump del database
    """
    command = f"mysql -u {username} -p{password} {database_name} < {input_file}"
    subprocess.run(command, shell=True)

# Esempio di utilizzo
if __name__ == "__main__":
    username = "root"
    password = "MyPassword"
    database_name = "mydatabase"
    input_file = "mydatabase_dump.sql"
    
    import_mysql_database(username, password, database_name, input_file)

