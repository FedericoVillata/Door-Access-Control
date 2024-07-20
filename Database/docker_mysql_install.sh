#!/bin/bash

# Verifica se Docker è installato
if ! command -v docker &> /dev/null
then
    echo "Docker non è installato. Assicurati di averlo installato prima di eseguire questo script."
    exit 1
fi

# Nome del container MySQL
container_name="mysql-container"

# Verifica se il container è già in esecuzione
if docker ps -a --format '{{.Names}}' | grep -Eq "^$container_name$"; then
    echo "Container $container_name è già presente. Rimuovendo il container esistente..."
    docker stop $container_name &> /dev/null
    docker rm $container_name &> /dev/null
fi

# Avvia un nuovo container MySQL senza password
echo "Avvio del container MySQL senza password..."
docker run --name $container_name -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -d -p 3306:3306 mysql

# Controllo dell'avvio del container
if [ $? -eq 0 ]; then
    echo "Container MySQL è stato avviato con successo."
else
    echo "Errore durante l'avvio del container MySQL."
fi
