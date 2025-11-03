#!/bin/bash
# Script per diagnosticare problemi con backend e frontend

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[1;34m'
NC='\033[0m'

info() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

warn() {
    echo -e "${YELLOW}!${NC} $1"
}

section() {
    echo ""
    echo -e "${BLUE}═══ $1 ═══${NC}"
}

section "1. Stato Servizi"
for service in armnas-backend nginx; do
    if systemctl is-active --quiet $service; then
        info "$service è attivo"
    else
        error "$service NON è attivo"
        echo "  Logs:"
        journalctl -u $service -n 10 --no-pager
    fi
done

section "2. Test Backend (porta 8000)"
if curl -f -s http://localhost:8000/api/ > /dev/null 2>&1; then
    info "Backend risponde su porta 8000"
else
    error "Backend NON risponde su porta 8000"
    warn "Prova: curl http://localhost:8000/api/"
fi

section "3. Test Nginx"
if curl -f -s http://localhost/ > /dev/null 2>&1; then
    info "Nginx risponde (frontend)"
else
    error "Nginx NON risponde"
fi

if curl -f -s http://localhost/api/ > /dev/null 2>&1; then
    info "Nginx proxy API funziona"
else
    error "Nginx proxy API NON funziona"
    warn "Prova: curl http://localhost/api/"
fi

section "4. Directory Log"
if [ -d /var/log/nginx ]; then
    info "/var/log/nginx esiste"
    ls -la /var/log/nginx 2>&1 | head -5
else
    error "/var/log/nginx NON esiste"
    warn "Esegui: sudo mkdir -p /var/log/nginx"
fi

section "5. Test API Specifiche"
echo "Test /api/system/overlayfs/status:"
curl -s http://localhost/api/system/overlayfs/status || echo "  Errore"

section "6. Log Backend (ultimi 20 righe)"
journalctl -u armnas-backend -n 20 --no-pager

section "7. Errori Nginx"
if [ -f /var/log/nginx/error.log ]; then
    tail -20 /var/log/nginx/error.log
else
    warn "File error.log non trovato"
fi

section "Soluzioni Rapide"
echo ""
echo "Se il backend non parte:"
echo "  sudo systemctl restart armnas-backend"
echo "  sudo journalctl -u armnas-backend -f"
echo ""
echo "Se nginx ha problemi:"
echo "  sudo mkdir -p /var/log/nginx"
echo "  sudo systemctl restart nginx"
echo ""
echo "Se /var/log è su zram e vuoto:"
echo "  sudo bash /usr/local/bin/fix-zram-directories.sh"
echo ""

