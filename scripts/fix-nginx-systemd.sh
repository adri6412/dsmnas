#!/bin/bash
# Fix nginx systemd service - risolve problema blocco su start

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

if [ "$EUID" -ne 0 ]; then 
    error "Questo script deve essere eseguito come root"
fi

echo "=========================================="
echo "  Fix Nginx Systemd Service"
echo "=========================================="
echo ""

# Backup servizio originale
if [ -f /lib/systemd/system/nginx.service ]; then
    info "Backup servizio originale..."
    cp /lib/systemd/system/nginx.service /lib/systemd/system/nginx.service.backup
fi

# Crea override service migliorato
info "Creazione override service..."
mkdir -p /etc/systemd/system/nginx.service.d

cat > /etc/systemd/system/nginx.service.d/override.conf << 'EOF'
[Service]
# Fix per problema blocco systemd start
# Usa Type=simple invece di forking per evitare problemi PID file
Type=simple
ExecStart=
ExecStart=/usr/sbin/nginx -g 'daemon off;'
# Rimuovi PIDFile (non necessario con Type=simple)
PIDFile=
# Aumenta timeout
TimeoutStartSec=30
TimeoutStopSec=30
# Restart automatico in caso di crash
Restart=on-failure
RestartSec=5s
EOF

info "✓ Override creato in /etc/systemd/system/nginx.service.d/override.conf"

# Ricarica systemd
info "Ricarica systemd daemon..."
systemctl daemon-reload

# Test configurazione nginx
info "Test configurazione nginx..."
if nginx -t; then
    info "✓ Configurazione nginx valida"
else
    error "Configurazione nginx non valida! Correggi prima di riavviare"
fi

# Riavvia nginx
info "Riavvio nginx..."
systemctl restart nginx

# Verifica stato
sleep 2
if systemctl is-active --quiet nginx; then
    info "✅ Nginx avviato con successo!"
    systemctl status nginx --no-pager -l
else
    error "Nginx non è riuscito ad avviarsi. Controlla i log: journalctl -u nginx -n 50"
fi

echo ""
info "Fix applicato con successo!"
info ""
info "Backup originale: /lib/systemd/system/nginx.service.backup"
info "Override attivo: /etc/systemd/system/nginx.service.d/override.conf"
echo ""

