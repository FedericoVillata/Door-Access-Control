import subprocess

def export_mysql_database(username, password, database_name, output_file):
    """
    Esporta un database MySQL utilizzando mysqldump.
    
    :param username: Nome utente del database MySQL
    :param password: Password del database MySQL
    :param database_name: Nome del database da esportare
    :param output_file: Percorso del file di output dove salvare il dump
    """
    command = f"mysqldump -u {username} -p{password} {database_name} > {output_file}"
    subprocess.run(command, shell=True)

# Esempio di utilizzo
if __name__ == "__main__":
    username = "root"
    password = "MyPassword"
    database_name = "mydatabase"
    output_file = "mydatabase_dump.sql"
    
    export_mysql_database(username, password, database_name, output_file)

