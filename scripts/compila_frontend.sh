#!/bin/bash

# Script per compilare il frontend di ArmNAS
# Questo script deve essere eseguito come root

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

echo -e "${GREEN}[INFO]${NC} Compilazione del frontend ArmNAS..."

# Directory di installazione
INSTALL_DIR="/opt/armnas"
FRONTEND_DIR="$INSTALL_DIR/frontend"
REPO_DIR=$(dirname $(readlink -f $0))

# Compila il frontend
echo -e "${GREEN}[INFO]${NC} Compilazione del frontend..."
cd $REPO_DIR/frontend
npm install
NODE_OPTIONS=--openssl-legacy-provider npm run build

# Verifica se la compilazione è riuscita
if [ -d "$REPO_DIR/frontend/dist" ] && [ "$(ls -A $REPO_DIR/frontend/dist)" ]; then
    echo -e "${GREEN}[INFO]${NC} Compilazione riuscita. Copia dei file..."
    
    # Rimuovi i vecchi file
    rm -rf $FRONTEND_DIR/*
    
    # Copia i file compilati
    cp -r $REPO_DIR/frontend/dist/* $FRONTEND_DIR/
    
    # Imposta i permessi corretti
    chown -R www-data:www-data $FRONTEND_DIR
    chmod -R 755 $FRONTEND_DIR
    
    echo -e "${GREEN}[OK]${NC} Frontend compilato e copiato con successo!"
else
    echo -e "${RED}[ERRORE]${NC} Compilazione fallita. Controlla gli errori sopra."
    exit 1
fi

# Riavvia Nginx
echo -e "${GREEN}[INFO]${NC} Riavvio di Nginx..."
systemctl restart nginx

echo -e "${GREEN}[OK]${NC} Operazione completata!"
echo ""
echo "Per accedere all'interfaccia web di ArmNAS, apri un browser e vai a:"
echo "http://$(hostname -I | awk '{print $1}')"