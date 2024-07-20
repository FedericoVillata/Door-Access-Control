#!/bin/bash

# Nome del contenitore Docker MySQL
CONTAINER_NAME="mysql-container"

# Porta sulla quale esporre MySQL (sostituiscila con la porta desiderata)
MYSQL_PORT="3306"

# Password per l'accesso al database MySQL (lascialo vuoto se non c'è una password)
#MYSQL_ROOT_PASSWORD="password"

# Avvia il contenitore Docker MySQL
#docker run -d --name "$CONTAINER_NAME" -p "$MYSQL_PORT:3306" -e MYSQL_ROOT_PASSWORD="$MYSQL_ROOT_PASSWORD" mysql:latest
docker run -d --name "$CONTAINER_NAME" -p "$MYSQL_PORT:3306"  mysql:latest


echo "Container MySQL avviato con successo."

