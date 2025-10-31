#!/bin/bash

# Script per disattivare overlayfs/overlayroot

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica root
if [ "$EUID" -ne 0 ]; then
    error "Questo script deve essere eseguito come root (usa sudo)"
    exit 1
fi

info "Disattivazione overlayfs/overlayroot..."

# 1. Disabilita overlayroot se configurato
if [ -f "/etc/overlayroot.conf" ]; then
    info "Disabilitazione overlayroot..."
    
    # Backup della configurazione
    if [ ! -f "/etc/overlayroot.conf.bak" ]; then
        cp /etc/overlayroot.conf /etc/overlayroot.conf.bak
        info "Backup creato: /etc/overlayroot.conf.bak"
    fi
    
    # Disabilita overlayroot commentando la configurazione
    sed -i 's/^overlayroot=/#overlayroot=/' /etc/overlayroot.conf || true
    
    # Oppure rimuovi completamente
    # rm /etc/overlayroot.conf
    
    info "✓ overlayroot disabilitato in /etc/overlayroot.conf"
    warn "  Riavvia il sistema per applicare le modifiche"
fi

# 2. Disabilita servizi overlayfs manuali
if systemctl is-enabled overlayfs.service &>/dev/null; then
    info "Disabilitazione servizio overlayfs.service..."
    systemctl stop overlayfs.service 2>/dev/null || true
    systemctl disable overlayfs.service 2>/dev/null || true
    info "✓ overlayfs.service disabilitato"
fi

# 3. Disabilita bind-armnas (non più necessario se overlay è disabilitato)
if systemctl is-enabled bind-armnas.service &>/dev/null; then
    warn "bind-armnas.service è abilitato."
    warn "Questo servizio monta /opt/armnas e /storage dalla SD originale."
    read -p "Vuoi disabilitare anche bind-armnas.service? (s/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[SsYy]$ ]]; then
        systemctl stop bind-armnas.service 2>/dev/null || true
        systemctl disable bind-armnas.service 2>/dev/null || true
        info "✓ bind-armnas.service disabilitato"
    else
        info "bind-armnas.service lasciato abilitato (utile anche senza overlay)"
    fi
fi

# 4. Verifica mount overlay attivi
info "Verifica mount overlay attivi..."
if mount | grep -q "overlay\|overlayroot"; then
    warn "Trovati mount overlay attivi:"
    mount | grep "overlay\|overlayroot" || true
    warn "I mount overlay rimarranno attivi fino al prossimo riavvio"
else
    info "✓ Nessun mount overlay attivo"
fi

# 5. Istruzioni per riavvio
echo ""
info "=== Istruzioni ==="
info "1. Riavvia il sistema per disattivare completamente overlayfs:"
info "   sudo reboot"
info ""
info "2. Dopo il riavvio, overlayfs sarà disattivato e tutte le scritture"
info "   andranno direttamente sulla SD card."
info ""
warn "ATTENZIONE: Senza overlayfs, tutte le scritture andranno sulla SD."
warn "Assicurati di avere una SD di buona qualità e considera di:"
warn "  - Configurare logrotate per limitare i log"
warn "  - Disabilitare servizi non necessari"
warn "  - Usare /storage (ZFS) per i dati importanti"

