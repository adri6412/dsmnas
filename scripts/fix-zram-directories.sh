#!/bin/bash
# Script per ricreare directory necessarie dopo mount zram
# Alcuni servizi (nginx, samba, ecc.) hanno bisogno delle loro directory in /var/log

set -e

# Colori
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

info "=== Creazione Directory Post-zram Mount ==="
echo ""

# Lista delle directory da creare
DIRECTORIES=(
    "/var/log/nginx"
    "/var/log/samba"
    "/var/log/apt"
    "/var/log/docker"
    "/var/cache/apt/archives/partial"
    "/var/cache/debconf"
    "/var/tmp"
)

# Crea le directory se non esistono
for dir in "${DIRECTORIES[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        info "✓ Creato: $dir"
    else
        info "✓ Esiste: $dir"
    fi
done

# Imposta permessi corretti
chmod 755 /var/log/nginx 2>/dev/null || true
chmod 755 /var/log/samba 2>/dev/null || true
chmod 1777 /var/tmp 2>/dev/null || true

info "✓ Directory post-zram create"

