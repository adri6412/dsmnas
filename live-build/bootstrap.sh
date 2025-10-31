#!/bin/bash
# Script per creare un'immagine Debian con live-build
# Supporto ZFS + Virtual DSM auto-installer

set -e

# Colori
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[BUILD]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Verifica prerequisiti
check_prerequisites() {
    log "Verifica prerequisiti..."
    
    local missing=()
    
    for cmd in lb debian-keyring; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        error "Pacchetti mancanti: ${missing[*]}"
        log "Installa con: sudo apt-get install live-build debian-keyring"
    fi
    
    log "Prerequisiti OK"
}

# Pulisci build precedenti
clean_previous() {
    log "Pulizia build precedenti..."
    lb clean --purge 2>/dev/null || true
    rm -rf .build 2>/dev/null || true
}

# Configurazione live-build
configure_live_build() {
    log "Configurazione live-build..."
    
    # Configurazione base
    lb config --architectures amd64 \
              --binary-images iso-hybrid \
              --distribution bookworm \
              --bootloader grub-pc \
              --archive-areas "main contrib non-free-firmware" \
              --mirror-bootstrap "http://deb.debian.org/debian" \
              --mirror-chroot-security "http://security.debian.org/debian-security" \
              --mirror-chroot-updates "http://deb.debian.org/debian" \
              --mirror-binary "http://deb.debian.org/debian" \
              --mirror-binary-security "http://security.debian.org/debian-security" \
              --mirror-binary-updates "http://deb.debian.org/debian" \
              --compression xz \
              --debian-installer live \
              --system live \
              --iso-volume "ArmNAS-DSM-Installer" \
              --iso-publisher "ArmNAS Project" \
              --iso-application "ZFS NAS with Virtual DSM" \
              --iso-preparer "live-build" || error "Errore nella configurazione"
}

# Configura autologin
setup_autologin() {
    log "Configurazione autologin..."
    
    mkdir -p config/includes.chroot/etc/systemd/system/getty@tty1.service.d
    
    cat > config/includes.chroot/etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
Type=simple
EOF

    log "Autologin configurato per root"
}

# Configura hook di avvio
setup_startup_hook() {
    log "Configurazione hook di avvio..."
    
    mkdir -p config/includes.chroot/etc/systemd/system
    
    cat > config/includes.chroot/etc/systemd/system/auto-install-dsm.service << 'EOF'
[Unit]
Description=Auto-install Virtual DSM
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/root/auto-install-dsm.sh
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
EOF

    mkdir -p config/hooks/
    
    cat > config/hooks/0100-enable-auto-install.hook.chroot << 'EOF'
#!/bin/bash
# Enable auto-install service
systemctl enable auto-install-dsm.service
EOF

    chmod +x config/hooks/0100-enable-auto-install.hook.chroot
    
    log "Hook di avvio configurato"
}

# Configura hook per disattivare autologin
setup_disable_autologin_hook() {
    log "Configurazione disabilitazione autologin..."
    
    mkdir -p config/hooks/
    
    cat > config/hooks/0200-disable-autologin.hook.chroot << 'EOF'
#!/bin/bash
# Script da aggiungere a auto-install-dsm.sh per disabilitare autologin
# Questo sarà eseguito dopo l'installazione

DISABLE_AUTOLOGIN_SCRIPT=/usr/local/bin/disable-autologin.sh

cat > "$DISABLE_AUTOLOGIN_SCRIPT" << 'INNER_EOF'
#!/bin/bash
# Disabilita autologin dopo installazione

rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -f /etc/systemd/system/getty@tty1.service.d/override.conf

systemctl daemon-reload
systemctl disable auto-install-dsm.service

rm -f /etc/systemd/system/auto-install-dsm.service

log "Autologin disabilitato"
INNER_EOF

chmod +x "$DISABLE_AUTOLOGIN_SCRIPT"

# Questo script verrà chiamato da auto-install-dsm.sh dopo l'installazione
EOF

    chmod +x config/hooks/0200-disable-autologin.hook.chroot
    
    log "Hook disabilitazione configurato"
}

# Aggiungi pacchetti
add_packages() {
    log "Configurazione pacchetti..."
    
    cat > config/package-lists/zfs-nas.list.chroot << 'EOF'
# Base packages
bash
curl
wget
git
vim
nano
sudo
openssh-server
net-tools

# ZFS support
zfsutils-linux
zfs-initramfs
zfs-dkms

# Docker
docker.io
docker-compose

# Build tools
build-essential
linux-headers-amd64

# Network tools
net-tools
iputils-ping
EOF

    log "Lista pacchetti creata"
}

# Aggiungi firmware per ZFS
add_firmware() {
    log "Configurazione firmware..."
    
    cat > config/package-lists/firmware.list.chroot << 'EOF'
# Firmware per ZFS e storage
firmware-linux-nonfree
EOF

    log "Firmware configurato"
}

# Main build process
main() {
    log "=== Build ArmNAS DSM Installer ==="
    
    check_prerequisites
    clean_previous
    configure_live_build
    setup_autologin
    setup_startup_hook
    setup_disable_autologin_hook
    add_packages
    add_firmware
    
    log "=== Build completato - Esegui: lb build ==="
    log "Prossimo passo: sudo lb build"
}

# Esegui main
main

