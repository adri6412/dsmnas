#!/bin/bash
# Fix Docker storage driver - cambia da ZFS a overlay2 per evitare snapshot automatiche

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

# Modalità automatica (senza conferme)
AUTO_MODE=false
if [ "$1" = "--auto" ]; then
    AUTO_MODE=true
fi

echo "=========================================="
echo "  Fix Docker Storage Driver"
echo "=========================================="
echo ""

# Verifica storage driver attuale
CURRENT_DRIVER=$(docker info 2>/dev/null | grep "Storage Driver" | awk '{print $3}')

info "Storage driver attuale: $CURRENT_DRIVER"

if [ "$CURRENT_DRIVER" = "zfs" ]; then
    warn "Docker sta usando ZFS come storage driver"
    warn "Questo crea snapshot automatiche per ogni container layer!"
    echo ""
    warn "SOLUZIONE: Cambiare a overlay2 (consigliato)"
    echo ""
    
    if [ "$AUTO_MODE" = "false" ]; then
        read -p "Vuoi cambiare Docker storage driver a overlay2? [s/N] " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Ss]$ ]]; then
            info "Operazione annullata"
            exit 0
        fi
    else
        info "Modalità automatica: cambio storage driver a overlay2..."
    fi
    
    info "Arresto Docker..."
    systemctl stop docker
    
    info "Backup configurazione Docker..."
    mkdir -p /root/docker-backup
    cp -r /var/lib/docker /root/docker-backup/docker-$(date +%Y%m%d_%H%M%S) || true
    
    info "Configurazione overlay2..."
    mkdir -p /etc/docker
    
    cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "data-root": "/storage/docker"
}
EOF
    
    info "Riavvio Docker..."
    systemctl start docker
    
    # Verifica nuovo driver
    sleep 3
    NEW_DRIVER=$(docker info 2>/dev/null | grep "Storage Driver" | awk '{print $3}')
    
    if [ "$NEW_DRIVER" = "overlay2" ]; then
        info "✅ Storage driver cambiato con successo a overlay2"
        info ""
        warn "IMPORTANTE: Dovrai ricreare i container esistenti!"
        warn "I dati in /storage sono al sicuro, ma i container devono essere ricreati"
        echo ""
        info "Per DSM:"
        echo "  cd /opt/armnas"
        echo "  docker compose down"
        echo "  docker compose up -d"
    else
        error "Cambio storage driver fallito. Driver attuale: $NEW_DRIVER"
    fi
    
elif [ "$CURRENT_DRIVER" = "overlay2" ]; then
    info "✅ Storage driver già configurato correttamente (overlay2)"
    info "   Nessuna snapshot automatica Docker"
else
    warn "Storage driver sconosciuto: $CURRENT_DRIVER"
fi

echo ""

