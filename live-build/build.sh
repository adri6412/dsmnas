#!/bin/bash
# Script completo per build ISO Debian con Virtual DSM
# Esegue automaticamente tutta la procedura

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

# Verifica root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        error "Questo script deve essere eseguito come root (usa sudo)"
    fi
}

# Verifica prerequisiti
check_prerequisites() {
    log "Verifica prerequisiti..."
    
    local missing=()
    
    for cmd in lb debootstrap debian-keyring; do
        if ! command -v $cmd >/dev/null 2>&1; then
            missing+=($cmd)
        fi
    done
    
    if [ ${#missing[@]} -ne 0 ]; then
        log "Installazione prerequisiti mancanti..."
        apt-get update
        apt-get install -y live-build live-boot live-config debian-keyring debootstrap
    fi
    
    log "Prerequisiti OK"
}

# Verifica installer_dsm.sh
check_installer() {
    log "Verifica installer_dsm.sh..."
    
    if [ ! -f "../scripts/installer_dsm.sh" ]; then
        error "installer_dsm.sh non trovato in ../scripts/"
    fi
    
    if ! file "../scripts/installer_dsm.sh" | grep -q "Makeself"; then
        log "⚠️  installer_dsm.sh potrebbe non essere un file makeself valido"
    fi
    
    log "✓ installer_dsm.sh trovato"
}

# Pulisci build precedenti
clean_build() {
    log "Pulizia build precedenti..."
    lb clean --purge 2>/dev/null || true
    rm -rf .build binary* *.iso 2>/dev/null || true
    log "Build precedenti rimossi"
}

# Configurazione live-build
configure_build() {
    log "Configurazione live-build..."
    
    # Crea directory config se non esiste
    mkdir -p config
    
    # Crea file di preferenze APT per escludere ubuntu-keyring PRIMA di lb config
    # Questo file verrà incluso nel chroot durante il bootstrap
    mkdir -p config/includes.chroot/etc/apt/preferences.d
    cat > config/includes.chroot/etc/apt/preferences.d/99-exclude-ubuntu-packages << 'EOF'
# Escludi pacchetti Ubuntu-specific che non esistono in Debian
Package: ubuntu-keyring
Pin: release *
Pin-Priority: -1
EOF
    
    # Configurazione base
    if ! lb config --architectures amd64 \
              --binary-images iso-hybrid \
              --distribution bookworm \
              --bootloader grub-pc \
              --archive-areas "main contrib non-free-firmware" \
              --mirror-bootstrap "http://deb.debian.org/debian" \
              --mirror-chroot-security "http://security.debian.org/debian-security" \
              --mirror-binary "http://deb.debian.org/debian" \
              --mirror-binary-security "http://security.debian.org/debian-security" \
              --compression xz \
              --debian-installer live \
              --system live \
              --iso-volume "ArmNAS-DSM-Installer" \
              --iso-publisher "ArmNAS Project" \
              --iso-application "ZFS NAS with Virtual DSM" \
              --iso-preparer "live-build" 2>&1 | tee -a build.log; then
        error "lb config fallito! Controlla build.log per dettagli"
    fi
    
    log "Configurazione completata"
}

# Setup autologin
setup_autologin() {
    log "Configurazione autologin per root..."
    
    mkdir -p config/includes.chroot/etc/systemd/system/getty@tty1.service.d
    
    cat > config/includes.chroot/etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I $TERM
Type=simple
EOF

    log "✓ Autologin configurato"
}

# Setup auto-install service
setup_auto_install_service() {
    log "Configurazione servizio auto-install..."
    
    mkdir -p config/includes.chroot/etc/systemd/system
    
    cat > config/includes.chroot/etc/systemd/system/auto-install-dsm.service << 'EOF'
[Unit]
Description=Auto-install Virtual DSM on First Boot
After=network-online.target local-fs.target systemd-udev-settle.service
Wants=network-online.target
Conflicts=shutdown.target
Before=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/root/auto-install-dsm.sh
StandardOutput=journal+console
StandardError=journal+console
TimeoutStartSec=3600
TimeoutStopSec=30
Restart=no

[Install]
WantedBy=multi-user.target
EOF

    log "✓ Servizio auto-install creato"
}

# Setup hooks
setup_hooks() {
    log "Configurazione hooks..."
    
    mkdir -p config/hooks/
    
    # Hook per abilitare il servizio
    cat > config/hooks/0100-enable-auto-install.hook.chroot << 'EOF'
#!/bin/bash
systemctl enable auto-install-dsm.service
EOF

    chmod +x config/hooks/0100-enable-auto-install.hook.chroot
    
    # Hook per creare script disabilitazione autologin
    cat > config/hooks/0200-create-disable-autologin.hook.chroot << 'EOF'
#!/bin/bash
cat > /usr/local/bin/disable-autologin.sh << 'INNER_EOF'
#!/bin/bash
# Disabilita autologin dopo installazione
rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
systemctl daemon-reload
systemctl disable auto-install-dsm.service 2>/dev/null || true
INNER_EOF
chmod +x /usr/local/bin/disable-autologin.sh
EOF

    chmod +x config/hooks/0200-create-disable-autologin.hook.chroot
    
    # Hook per preparare l'ambiente (crea directory, verifica script)
    cat > config/hooks/0300-prepare-auto-install.hook.chroot << 'EOF'
#!/bin/bash
# Prepara l'ambiente per auto-install
set -e

# Crea directory per flag file
mkdir -p /var/lib/armnas

# Assicura che gli script siano eseguibili
if [ -f /root/auto-install-dsm.sh ]; then
    chmod +x /root/auto-install-dsm.sh
fi

if [ -f /root/installer_dsm.sh ]; then
    chmod +x /root/installer_dsm.sh
fi

# Verifica che bash sia disponibile
if ! command -v bash >/dev/null 2>&1; then
    echo "WARNING: bash non trovato, potrebbe essere necessario per auto-install-dsm.sh"
fi
EOF

    chmod +x config/hooks/0300-prepare-auto-install.hook.chroot
    
    # Hook per applicare preferenze APT ed escludere ubuntu-keyring
    # Questo hook viene eseguito PRIMA dell'installazione dei pacchetti
    cat > config/hooks/0100-exclude-ubuntu-packages.hook.chroot << 'EOF'
#!/bin/bash
# Assicura che ubuntu-keyring sia escluso PRIMA dell'installazione pacchetti
set -e

# Verifica che il file di preferenze sia presente
if [ ! -f /etc/apt/preferences.d/99-exclude-ubuntu-packages ]; then
    mkdir -p /etc/apt/preferences.d
    cat > /etc/apt/preferences.d/99-exclude-ubuntu-packages << 'PREFEOF'
Package: ubuntu-keyring
Pin: release *
Pin-Priority: -1
PREFEOF
fi

# Aggiorna cache APT dopo aver impostato le preferenze
apt-get update || true
EOF

    chmod +x config/hooks/0100-exclude-ubuntu-packages.hook.chroot
    
    log "✓ Hooks configurati"
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

# Utilities
htop
iotop
EOF

    cat > config/package-lists/firmware.list.chroot << 'EOF'
# Firmware per storage e network
firmware-linux-nonfree
firmware-linux-free
EOF

    # Escludi pacchetti Ubuntu-specific che non esistono in Debian
    # In live-build, i file .excludes.chroot escludono pacchetti
    cat > config/package-lists/ubuntu-excludes.excludes.chroot << 'EOF'
# Escludi pacchetti Ubuntu-specific non disponibili in Debian
ubuntu-keyring
EOF

    log "✓ Pacchetti configurati"
}

# Copia file necessari
copy_files() {
    log "Copia file necessari..."
    
    # Copia auto-install script
    if [ -f "auto-install-dsm.sh" ]; then
        mkdir -p config/includes.chroot/root
        cp auto-install-dsm.sh config/includes.chroot/root/
        chmod +x config/includes.chroot/root/auto-install-dsm.sh
        log "✓ auto-install-dsm.sh copiato"
    fi
    
    # Copia installer_dsm.sh
    if [ -f "../scripts/installer_dsm.sh" ]; then
        mkdir -p config/includes.chroot/root
        cp ../scripts/installer_dsm.sh config/includes.chroot/root/
        chmod +x config/includes.chroot/root/installer_dsm.sh
        log "✓ installer_dsm.sh copiato"
    else
        error "installer_dsm.sh non trovato in ../scripts/!"
    fi
}

# Esegui build
run_build() {
    log "=== INIZIO BUILD ==="
    log "Questo processo richiederà 30-60 minuti..."
    log "Assicurati di avere almeno 15GB di spazio libero"
    log ""
    
    lb build 2>&1 | tee -a build.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log ""
        log "=== BUILD COMPLETATO CON SUCCESSO ==="
        
        if [ -f "binary-hybrid.iso" ]; then
            ISO_SIZE=$(du -h binary-hybrid.iso | cut -f1)
            log "Immagine ISO creata: binary-hybrid.iso ($ISO_SIZE)"
            ls -lh binary-hybrid.iso
        fi
    else
        error "Build fallito! Controlla build.log per dettagli"
    fi
}

# Main
main() {
    log "===================================================="
    log "  ArmNAS Virtual DSM ISO Builder"
    log "===================================================="
    log ""
    
    check_root
    check_prerequisites
    check_installer
    clean_build
    configure_build
    setup_autologin
    setup_auto_install_service
    setup_hooks
    add_packages
    copy_files
    run_build
    
    log ""
    log "===================================================="
    log "  Build completato!"
    log "  ISO: $(pwd)/binary-hybrid.iso"
    log "===================================================="
}

# Esegui
main

