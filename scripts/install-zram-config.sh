#!/bin/bash
# Script per installare e configurare zram-config
# Riferimento: https://github.com/ecdye/zram-config
# 
# zram-config è una soluzione completa per gestire zram per:
# - Swap compresso in RAM (invece di swap su SD - riduce usura)
# - Directory in RAM compresso (es. /var/log)
# - Supporto per log rotation automatica

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
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

info "=== Installazione zram-config ==="
info "Riferimento: https://github.com/ecdye/zram-config"
echo ""

# Verifica se già installato
if [ -f "/usr/local/bin/zram-config" ] && systemctl is-active --quiet zram-config.service; then
    info "zram-config è già installato e attivo"
    zramctl 2>/dev/null || warn "zramctl non disponibile - installa util-linux"
    exit 0
fi

# Installa dipendenze
info "Installazione dipendenze..."
apt-get update
apt-get install -y git util-linux rsync || {
    error "Impossibile installare dipendenze"
    exit 1
}

# Clone del repository (se non esiste già)
ZRAM_REPO_DIR="/tmp/zram-config"
if [ -d "$ZRAM_REPO_DIR" ]; then
    info "Repository zram-config già clonato, aggiorno..."
    cd "$ZRAM_REPO_DIR"
    git pull || warn "Impossibile aggiornare repository"
else
    info "Clone repository zram-config da GitHub..."
    git clone https://github.com/ecdye/zram-config.git "$ZRAM_REPO_DIR" || {
        error "Impossibile clonare repository"
        exit 1
    }
    cd "$ZRAM_REPO_DIR"
fi

# Esegui script di installazione
info "Esecuzione script di installazione..."
if [ -f "install.bash" ]; then
    bash install.bash || {
        error "Installazione fallita"
        exit 1
    }
else
    error "Script install.bash non trovato"
    exit 1
fi

# Configurazione personalizzata per ARM NAS
info "Configurazione zram per ARM NAS..."

# Backup configurazione originale
if [ -f "/etc/ztab" ] && [ ! -f "/etc/ztab.orig" ]; then
    cp /etc/ztab /etc/ztab.orig
    info "Backup configurazione originale in /etc/ztab.orig"
fi

# Configura /etc/ztab per ARM NAS
# Swap: 1GB compresso con lzo-rle (massima velocità)
# Log: 150MB compresso per /var/log con rotation su /opt/zram/oldlog
cat > /etc/ztab << 'ZTAB'
# zram configuration for ARM NAS
# Formato: tipo alg mem_limit disk_size [opzioni specifiche]
# 
# Algoritmi disponibili:
# - lzo-rle: più veloce, compressione decente (raccomandato)
# - lzo: veloce, compressione simile a lzo-rle
# - lz4: molto veloce, compressione leggermente inferiore
# - zstd: più lento, ma miglior compressione (ottimo per testo/log)
#
# mem_limit: limite di memoria compressa (hard limit)
# disk_size: dimensione massima non compressa (circa 150% di mem_limit)

# SWAP: zram swap device (priorità alta)
# 1GB RAM compressa, max 3GB non compressi
# Priorità 75 (più alta dello swap su disco)
# page-cluster 0: ottimizza per pagine singole (bassa latenza)
# swappiness 150: usa zram più aggressivamente (migliori performance)
swap	lzo-rle		1G		3G		75		0		150

# LOG: /var/log in zram con rotation automatica
# 150MB RAM compressa, max 450MB non compressi
# oldlog_dir: i log vecchi vanno su /opt/zram/oldlog (fuori dalla SD)
log	lzo-rle		150M		450M		/var/log	/opt/zram/oldlog

# DIRECTORY: Esempi di directory in zram (commentate di default)
# NON mettere /storage in zram! Deve rimanere disponibile per ZFS
# Esempi:
# dir	lzo-rle		50M		150M		/tmp
# dir	zstd		100M		300M		/var/cache

ZTAB

info "✓ Configurazione /etc/ztab creata"
info ""
info "Configurazione zram:"
info "  - Swap: 1GB RAM compressa (max 3GB non compressi) con priorità 75"
info "  - Log: 150MB RAM compressa (max 450MB non compressi) in /var/log"
info "  - Rotation log: log vecchi salvati in /opt/zram/oldlog"
info "  - /storage: NON in zram (disponibile per pool ZFS)"
echo ""

# Crea directory per log vecchi
mkdir -p /opt/zram/oldlog
info "✓ Directory /opt/zram/oldlog creata per log rotation"

# Abilita e avvia servizio
info "Abilitazione servizio zram-config..."
systemctl daemon-reload
systemctl enable zram-config.service || {
    warn "Impossibile abilitare servizio (potrebbe essere già abilitato)"
}

# Avvia il servizio
info "Avvio servizio zram-config..."
systemctl start zram-config.service || {
    error "Impossibile avviare servizio zram-config"
    error "Verifica i log con: journalctl -u zram-config.service"
    exit 1
}

# Attendi che il servizio si stabilizzi
sleep 2

# Verifica che zram sia attivo
info "Verifica stato zram..."
echo ""

if command -v zramctl >/dev/null 2>&1; then
    if zramctl | grep -q "zram"; then
        info "✅ zram attivo e funzionante:"
        echo ""
        zramctl
        echo ""
    else
        warn "zram installato ma nessun device attivo"
    fi
else
    warn "Comando zramctl non disponibile (installa util-linux)"
fi

# Verifica swap
if swapon --show | grep -q "zram"; then
    info "✅ Swap zram attivo:"
    swapon --show | grep zram
    echo ""
else
    warn "Swap zram non trovato"
fi

# Verifica /var/log
if mountpoint -q /var/log 2>/dev/null; then
    LOG_FSTYPE=$(findmnt -n -o FSTYPE /var/log 2>/dev/null || echo "unknown")
    if echo "$LOG_FSTYPE" | grep -q "overlay"; then
        info "✅ /var/log montato su zram (overlay):"
        df -h /var/log | tail -1
        echo ""
    else
        warn "/var/log montato ma non come overlay (tipo: $LOG_FSTYPE)"
    fi
fi

# Informazioni finali
echo ""
info "=== Installazione completata ==="
info ""
info "Vantaggi di zram-config:"
info "  ✅ Riduce drasticamente le scritture su SD card"
info "  ✅ Swap compresso in RAM invece che su disco"
info "  ✅ Log temporanei in RAM compressa"
info "  ✅ /storage libero per pool ZFS"
info ""
info "Comandi utili:"
info "  zramctl                    - Mostra dispositivi zram attivi"
info "  swapon --show              - Mostra swap attivo (incluso zram)"
info "  df -h                      - Mostra filesystem (incluso zram)"
info "  systemctl status zram-config - Stato del servizio"
info ""
info "Per modificare la configurazione:"
info "  1. sudo systemctl stop zram-config"
info "  2. sudo nano /etc/ztab"
info "  3. sudo systemctl start zram-config"
echo ""

# Cleanup
rm -rf "$ZRAM_REPO_DIR"
info "✓ File temporanei rimossi"

info "Installazione zram-config completata con successo!"

