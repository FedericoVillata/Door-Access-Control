#!/bin/bash

# Nome del contenitore Docker MySQL
CONTAINER_NAME="mysql-container"

# Arresta il contenitore Docker MySQL
docker stop "$CONTAINER_NAME"

echo "Container MySQL arrestato con successo."
