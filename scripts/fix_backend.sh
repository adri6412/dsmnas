#!/bin/bash

# Script per correggere e riavviare il backend

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

info "Verifica dello stato del backend..."
systemctl status armnas-backend

info "Riavvio del servizio backend..."
systemctl restart armnas-backend

if [ $? -eq 0 ]; then
    info "Backend riavviato con successo!"
else
    error "Errore nel riavvio del backend"
    warn "Tentativo di correzione..."
    
    # Verifica se il servizio è configurato correttamente
    cat > /etc/systemd/system/armnas-backend.service << EOF
[Unit]
Description=ArmNAS Backend Service
After=network.target

[Service]
User=root
WorkingDirectory=$BACKEND_DIR
ExecStart=$BACKEND_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

    info "Ricaricamento dei servizi systemd..."
    systemctl daemon-reload
    
    info "Riavvio del backend..."
    systemctl restart armnas-backend
    
    if [ $? -eq 0 ]; then
        info "Backend riavviato con successo dopo la correzione!"
    else
        error "Errore persistente nel backend"
        warn "Controlla i log con: journalctl -u armnas-backend -n 50"
    fi
fi

# Verifica se il backend è in ascolto sulla porta 8000
info "Verifica se il backend è in ascolto sulla porta 8000..."
netstat -tuln | grep 8000

if [ $? -eq 0 ]; then
    info "Il backend è in ascolto sulla porta 8000"
else
    warn "Il backend non sembra essere in ascolto sulla porta 8000"
    warn "Controlla i log con: journalctl -u armnas-backend -n 50"
fi

# Verifica se Nginx è configurato correttamente
info "Verifica della configurazione di Nginx..."
nginx -t

if [ $? -eq 0 ]; then
    info "La configurazione di Nginx è corretta"
    info "Riavvio di Nginx..."
    systemctl restart nginx
    
    if [ $? -eq 0 ]; then
        info "Nginx riavviato con successo!"
    else
        error "Errore nel riavvio di Nginx"
    fi
else
    error "La configurazione di Nginx contiene errori"
    warn "Esegui lo script fix_nginx.sh per correggere la configurazione"
fi

info "Test di connessione al backend..."
curl -I http://localhost:8000/api/test/ping

info "Test completo dell'API..."
curl http://localhost:8000/api/test/ping

info "Test dei servizi..."
curl http://localhost:8000/api/system/services

exit 0