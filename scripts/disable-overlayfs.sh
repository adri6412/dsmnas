#!/bin/bash
# Script per disabilitare overlayfs su sistemi ARM NAS legacy
# Usato per migrare da overlayfs a zram-config

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

info "=== Disabilitazione OverlayFS su ARM NAS ==="
echo ""
info "Questo script disabilita overlayfs e prepara il sistema per zram-config"
echo ""

# Verifica se overlayfs è attivo
OVERLAY_ACTIVE=false
if mount | grep -q "type overlay.*on /"; then
    OVERLAY_ACTIVE=true
    warn "OverlayFS è attivo sul sistema"
fi

# 1. Disabilita overlayroot se presente
if [ -f /etc/overlayroot.conf ]; then
    info "Disabilitazione overlayroot.conf..."
    echo 'overlayroot=""' > /etc/overlayroot.conf
    info "✓ overlayroot.conf disabilitato"
fi

# 2. Disabilita servizi overlayfs
info "Disabilitazione servizi overlayfs..."
for service in bind-armnas overlayfs overlayroot; do
    if systemctl is-enabled "$service.service" 2>/dev/null; then
        systemctl disable "$service.service" 2>/dev/null || true
        info "✓ Servizio $service.service disabilitato"
    fi
    if systemctl is-active "$service.service" 2>/dev/null; then
        systemctl stop "$service.service" 2>/dev/null || true
        info "✓ Servizio $service.service fermato"
    fi
done

# 3. Rimuovi script overlayfs
info "Rimozione script overlayfs..."
OVERLAY_SCRIPTS=(
    "/usr/local/bin/overlay-rw"
    "/usr/local/bin/overlay-ro"
    "/usr/local/bin/overlay-status"
    "/usr/local/bin/bind-armnas.sh"
    "/usr/local/bin/setup-overlayfs.sh"
    "/usr/local/bin/configure-overlay-mode.sh"
    "/usr/local/bin/mount-overlayfs.sh"
)

for script in "${OVERLAY_SCRIPTS[@]}"; do
    if [ -f "$script" ]; then
        rm -f "$script"
        info "✓ Rimosso $script"
    fi
done

# 4. Rimuovi alias overlay
if [ -f /etc/profile.d/overlay-ro-rw.sh ]; then
    rm -f /etc/profile.d/overlay-ro-rw.sh
    info "✓ Rimossi alias overlay (ro/rw)"
fi

# 5. Rimuovi hook initramfs per overlayfs
if [ -f /etc/initramfs-tools/hooks/configure-overlay-mode ]; then
    rm -f /etc/initramfs-tools/hooks/configure-overlay-mode
    info "✓ Rimosso hook initramfs"
fi

# 6. Rimuovi file di stato overlay
if [ -f /var/lib/overlay-state ]; then
    rm -f /var/lib/overlay-state
    info "✓ Rimosso file di stato overlay"
fi

# 7. Rimuovi directory overlay se vuote
OVERLAY_DIRS=(
    "/overlay/upper"
    "/overlay/work"
    "/overlay/upper-sd"
    "/overlay/work-sd"
    "/overlay/root"
)

for dir in "${OVERLAY_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # Smonta se è un mount point
        if mountpoint -q "$dir" 2>/dev/null; then
            umount "$dir" 2>/dev/null || umount -l "$dir" 2>/dev/null || true
            info "✓ Smontato $dir"
        fi
        # Rimuovi directory se vuota
        if [ -z "$(ls -A "$dir" 2>/dev/null)" ]; then
            rmdir "$dir" 2>/dev/null || true
            info "✓ Rimossa directory vuota $dir"
        else
            warn "Directory $dir non vuota - lasciata intatta"
        fi
    fi
done

# 8. Rimuovi servizi systemd overlayfs
OVERLAY_SERVICES=(
    "/etc/systemd/system/bind-armnas.service"
    "/etc/systemd/system/overlayfs.service"
)

for service_file in "${OVERLAY_SERVICES[@]}"; do
    if [ -f "$service_file" ]; then
        rm -f "$service_file"
        info "✓ Rimosso $service_file"
    fi
done

# 9. Aggiorna initramfs se necessario
if command -v update-initramfs >/dev/null 2>&1; then
    if [ -d /boot/initrd.img* ] || [ -f /boot/initrd.img-* ]; then
        info "Aggiornamento initramfs..."
        update-initramfs -u 2>/dev/null || warn "Impossibile aggiornare initramfs"
    fi
fi

# 10. Ricarica systemd
systemctl daemon-reload

echo ""
info "=== Disabilitazione Completata ==="
echo ""

if [ "$OVERLAY_ACTIVE" = "true" ]; then
    warn "⚠️  OverlayFS è ancora attivo in questo momento"
    warn "   È necessario riavviare per applicare le modifiche"
    echo ""
    info "Dopo il riavvio:"
    info "  1. Verifica che overlayfs non sia più attivo:"
    info "     mount | grep overlay"
    info "  2. Installa zram-config:"
    info "     sudo bash /opt/armnas/scripts/install-zram-config.sh"
    info "  3. Verifica che /storage sia libero per ZFS:"
    info "     mountpoint /storage"
    echo ""
    read -p "Vuoi riavviare ora? (s/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        info "Riavvio in 5 secondi..."
        sleep 5
        reboot
    else
        warn "Ricorda di riavviare manualmente per applicare le modifiche!"
    fi
else
    info "✅ OverlayFS non era attivo sul sistema"
    echo ""
    info "Prossimi passi:"
    info "  1. Installa zram-config (se non già fatto):"
    info "     sudo bash /opt/armnas/scripts/install-zram-config.sh"
    info "  2. Verifica che tutto funzioni:"
    info "     zramctl"
    info "     mountpoint /storage"
fi

echo ""
info "Per maggiori informazioni, leggi: /opt/armnas/docs/MIGRATION_OVERLAYFS_TO_ZRAM.md"

