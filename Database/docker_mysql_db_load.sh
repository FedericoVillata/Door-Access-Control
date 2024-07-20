#!/bin/bash

# Nome del file SQL da caricare
SQL_FILE="aziendadb.sql"

# Nome del contenitore Docker MySQL
CONTAINER_NAME="mysql-container"

# Percorso nel contenitore dove verrà copiato il file SQL
CONTAINER_PATH="/"

# Nome utente e password per accedere al database MySQL
MYSQL_USER="root"
MYSQL_PASSWORD=""

# Nome del database di destinazione
DATABASE_NAME="aziendaDB"

# Copia il file SQL nel contenitore Docker
docker cp "$SQL_FILE" "$CONTAINER_NAME:$CONTAINER_PATH/$SQL_FILE"


docker exec "$CONTAINER_NAME" bash -c "mysql -u$MYSQL_USER -e 'CREATE DATABASE IF NOT EXISTS $DATABASE_NAME;'"


# Esegue il dump SQL all'interno del contenitore Docker
#docker exec -i "$CONTAINER_NAME" bash -c "mysql -u$MYSQL_USER -p$MYSQL_PASSWORD $DATABASE_NAME < $CONTAINER_PATH/$SQL_FILE"
docker exec -i "$CONTAINER_NAME" bash -c "mysql -u$MYSQL_USER $DATABASE_NAME < $CONTAINER_PATH/$SQL_FILE"


# Rimuove il file SQL dal contenitore Docker
docker exec "$CONTAINER_NAME" rm "$CONTAINER_PATH/$SQL_FILE"

echo "Dump SQL caricato con successo nel database MySQL."
