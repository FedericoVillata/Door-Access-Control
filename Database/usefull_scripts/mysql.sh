#to access to a db
#mysql -u username -p -h hostname database_name
sudo mysql -u root -p -h localhost mydatabase


#######################
# to create a DB in sql

# 1. access in bash
mysql -u username -p

CREATE USER 'root'@'localhost' IDENTIFIED BY '';

# 2. create a new db in my sql :
CREATE DATABASE aziendadb;

# opt - verify if the database exists
SHOW DATABASES;


