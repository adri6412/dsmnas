#!/bin/bash

# Script per correggere la configurazione di Nginx

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
FRONTEND_DIR="$INSTALL_DIR/frontend"

info "Correzione della configurazione di Nginx..."

# Crea una nuova configurazione di Nginx
cat > /etc/nginx/sites-available/armnas << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Aumenta il buffer per evitare errori 413
    client_max_body_size 100M;

    # Servire i file statici del frontend
    location / {
        root $FRONTEND_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # Reindirizzare le richieste API al backend
    location /api/ {
        proxy_pass http://localhost:8000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 90;
        proxy_connect_timeout 90;
        proxy_buffering off;
    }
}
EOF

# Abilita il sito
ln -sf /etc/nginx/sites-available/armnas /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Verifica la configurazione
info "Verifica della configurazione di Nginx..."
nginx -t

if [ $? -eq 0 ]; then
    info "Riavvio di Nginx..."
    systemctl restart nginx
    
    if [ $? -eq 0 ]; then
        info "Nginx riavviato con successo!"
    else
        error "Errore nel riavvio di Nginx"
        warn "Controlla lo stato con: systemctl status nginx"
    fi
else
    error "La configurazione di Nginx contiene errori"
    warn "Correggi gli errori e riavvia Nginx manualmente"
fi

exit 0