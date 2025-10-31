#!/bin/bash

# Script per correggere i permessi dei file e delle directory

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi informativi
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Funzione per stampare avvisi
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Funzione per stampare errori
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica se lo script è eseguito come root
if [ "$EUID" -ne 0 ]; then
    error "Questo script deve essere eseguito come root"
    exit 1
fi

# Directory di installazione
INSTALL_DIR="/opt/armnas"
BACKEND_DIR="$INSTALL_DIR/backend"
FRONTEND_DIR="$INSTALL_DIR/frontend"

info "Correzione dei permessi per i file di ArmNAS..."

# Imposta i permessi corretti per le directory
chmod 755 $INSTALL_DIR
chmod 755 $BACKEND_DIR
chmod 755 $FRONTEND_DIR

# Imposta i permessi corretti per i file Python
find $BACKEND_DIR -type f -name "*.py" -exec chmod 644 {} \;

# Rendi eseguibili gli script
chmod +x $BACKEND_DIR/main.py

# Imposta i permessi corretti per l'ambiente virtuale
chmod -R 755 $BACKEND_DIR/venv

# Imposta i permessi corretti per i file del frontend
chmod -R 755 $FRONTEND_DIR

# Correggi i permessi per i file di configurazione
chmod 644 /etc/systemd/system/armnas-backend.service
chmod 644 /etc/nginx/sites-available/armnas
chmod 644 /etc/nginx/sites-enabled/armnas

# Riavvia i servizi
info "Riavvio dei servizi..."
systemctl daemon-reload
systemctl restart armnas-backend
systemctl restart nginx

info "Permessi corretti con successo!"
exit 0