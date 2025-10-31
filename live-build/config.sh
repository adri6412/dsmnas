#!/bin/bash
# Configurazione principale per live-build
# Questo script configura un'immagine Debian con supporto ZFS e auto-installazione DSM

set -e

# Variabili principali
LB_CONFIG_DIR="${LB_CONFIG_DIR:-config}"
ARCH="${ARCH:-amd64}"
MIRROR="${MIRROR:-http://deb.debian.org/debian}"
SUITE="${SUITE:-bookworm}"
LB_BOOTLOADER="${LB_BOOTLOADER:-grub-pc}"

# Pacchetti essenziali per ZFS
LB_PACKAGES_FIRMWARE="atmel-firmware firmware-atheros firmware-iwlwifi firmware-libertas firmware-misc-nonfree firmware-realtek"
LB_PACKAGES_ZFS="zfsutils-linux zfs-initramfs zfs-dkms"
LB_PACKAGES_DOCKER="docker.io docker-compose"
LB_PACKAGES_SYSTEM="bash curl wget git vim nano sudo openssh-server"

# Funzione per aggiungere file alla configurazione
add_file() {
    local src=$1
    local dst=$2
    
    mkdir -p "${LB_CONFIG_DIR}/$(dirname "$dst")"
    cp "$src" "${LB_CONFIG_DIR}/$dst"
}

# Crea la struttura directory
mkdir -p "${LB_CONFIG_DIR}"

# Copia lo script di auto-installazione
if [ -f "auto-install-dsm.sh" ]; then
    add_file "auto-install-dsm.sh" "chroot_local_includes/root/auto-install-dsm.sh"
    chmod +x "${LB_CONFIG_DIR}/chroot_local_includes/root/auto-install-dsm.sh"
fi

# Copia installer_dsm.sh se esiste
if [ -f "../scripts/installer_dsm.sh" ]; then
    add_file "../scripts/installer_dsm.sh" "chroot_local_includes/root/installer_dsm.sh"
    chmod +x "${LB_CONFIG_DIR}/chroot_local_includes/root/installer_dsm.sh"
fi

log "Configurazione live-build creata in ${LB_CONFIG_DIR}/"
log "Usa: lb config per configurarlo"

