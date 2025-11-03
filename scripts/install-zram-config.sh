#!/bin/bash
# Script per installare e configurare systemd-zram-generator
# 
# systemd-zram-generator è una soluzione semplice e affidabile per:
# - Swap compresso in RAM (invece di swap su SD - riduce usura)
# - Directory in RAM compressa (es. /var/log, /tmp)
# - Integrato con systemd (no compilazione richiesta)
# - Disponibile nei repository ufficiali Debian

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

info "=== Installazione systemd-zram-generator ==="
info "Riferimento: https://github.com/systemd/zram-generator"
echo ""

# Verifica se già installato
if command -v systemd-zram-generator >/dev/null 2>&1 && [ -f /etc/systemd/zram-generator.conf ]; then
    info "systemd-zram-generator è già installato e configurato"
    zramctl 2>/dev/null || warn "zramctl non disponibile - installa util-linux"
    info "Configurazione attuale:"
    cat /etc/systemd/zram-generator.conf 2>/dev/null || true
    exit 0
fi

# Installa systemd-zram-generator
info "Installazione systemd-zram-generator e dipendenze..."
apt-get update
apt-get install -y systemd-zram-generator util-linux || {
    error "Impossibile installare systemd-zram-generator"
    error "Verifica che sia disponibile nel repository Debian/Ubuntu"
    exit 1
}

# Verifica installazione
if ! command -v systemd-zram-generator >/dev/null 2>&1; then
    error "systemd-zram-generator non trovato dopo l'installazione"
    exit 1
fi

info "✓ systemd-zram-generator installato"

# Rileva RAM disponibile
info "Rilevamento RAM disponibile..."
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

info "RAM totale rilevata: ${TOTAL_RAM_GB}GB"

# Calcola dimensioni zram in base alla RAM
# - Swap: 25% della RAM totale (min 2GB, max 16GB)
# - Log: 512MB (sufficiente per la maggior parte dei casi)
# - Tmp: 2GB (temporanei)

if [ $TOTAL_RAM_GB -ge 64 ]; then
    # Sistema con 64GB+ RAM
    SWAP_SIZE=16384
    LOG_SIZE=1024
    TMP_SIZE=4096
elif [ $TOTAL_RAM_GB -ge 32 ]; then
    # Sistema con 32-63GB RAM
    SWAP_SIZE=8192
    LOG_SIZE=512
    TMP_SIZE=2048
elif [ $TOTAL_RAM_GB -ge 16 ]; then
    # Sistema con 16-31GB RAM
    SWAP_SIZE=4096
    LOG_SIZE=512
    TMP_SIZE=2048
else
    # Sistema con meno di 16GB RAM
    SWAP_SIZE=2048
    LOG_SIZE=256
    TMP_SIZE=1024
fi

info "Configurazione zram ottimizzata:"
info "  - Swap: ${SWAP_SIZE}MB"
info "  - Log: ${LOG_SIZE}MB"
info "  - Tmp: ${TMP_SIZE}MB"
echo ""

# Backup configurazione esistente
if [ -f "/etc/systemd/zram-generator.conf" ]; then
    cp /etc/systemd/zram-generator.conf /etc/systemd/zram-generator.conf.bak
    info "✓ Backup configurazione esistente"
fi

# Crea configurazione systemd-zram-generator
cat > /etc/systemd/zram-generator.conf << EOF
# ===============================
# ZRAM configuration for ARM NAS
# Generato automaticamente per sistema con ${TOTAL_RAM_GB}GB RAM
# ===============================

# Swap device - comprimi con zstd (miglior rapporto compressione/velocità)
# Priorità 100 (più alta dello swap su disco)
[zram0]
zram-size = ${SWAP_SIZE}
compression-algorithm = zstd
swap-priority = 100

# /var/log in RAM compressa
[zram1]
zram-size = ${LOG_SIZE}
compression-algorithm = zstd
mount-point = /var/log

# /tmp in RAM compressa
[zram2]
zram-size = ${TMP_SIZE}
compression-algorithm = zstd
mount-point = /tmp
EOF

info "✓ Configurazione /etc/systemd/zram-generator.conf creata"
echo ""
cat /etc/systemd/zram-generator.conf
echo ""

# Ricarica systemd per applicare la configurazione
info "Ricaricamento configurazione systemd..."
systemctl daemon-reload

# systemd-zram-generator viene eseguito automaticamente all'avvio
# Per applicare ora senza riavvio, eseguiamo manualmente
info "Generazione dispositivi zram..."

# Esegui generatore (se disponibile)
if [ -x /usr/lib/systemd/systemd-zram-generator ]; then
    /usr/lib/systemd/systemd-zram-generator || {
        warn "Generazione dispositivi fallita, riavvio consigliato"
    }
fi

# Attendi stabilizzazione
sleep 2

# Verifica che zram sia attivo
info "Verifica stato zram..."
echo ""

ZRAM_OK=false

if command -v zramctl >/dev/null 2>&1; then
    if zramctl 2>/dev/null | grep -q "zram"; then
        info "✅ Dispositivi zram attivi:"
        echo ""
        zramctl
        echo ""
        ZRAM_OK=true
    else
        warn "⚠️ Nessun dispositivo zram attivo"
        warn "   Potrebbe essere necessario riavviare per applicare la configurazione"
    fi
else
    warn "Comando zramctl non disponibile"
fi

# Verifica swap
if swapon --show 2>/dev/null | grep -q "zram"; then
    info "✅ Swap zram attivo:"
    swapon --show | grep zram
    echo ""
else
    if [ "$ZRAM_OK" = "false" ]; then
        warn "⚠️ Swap zram non trovato (riavvio necessario)"
    fi
fi

# Verifica mount /var/log e /tmp
for mount_point in /var/log /tmp; do
    if findmnt "$mount_point" 2>/dev/null | grep -q "zram"; then
        info "✅ $mount_point montato su zram:"
        df -h "$mount_point" | tail -1
    fi
done

# Informazioni finali
echo ""
info "=== Installazione completata ==="
echo ""

if [ "$ZRAM_OK" = "true" ]; then
    info "✅ systemd-zram-generator installato e configurato"
    info "   Dispositivi zram attivi e funzionanti"
else
    warn "⚠️  systemd-zram-generator installato ma dispositivi non attivi"
    warn "   Riavvia il sistema per applicare la configurazione:"
    warn "   sudo reboot"
fi

echo ""
info "Vantaggi di zram:"
info "  ✅ Riduce drasticamente le scritture su SD/SSD (~80%)"
info "  ✅ Swap compresso in RAM (20-40x più veloce)"
info "  ✅ /var/log e /tmp in RAM compressa"
info "  ✅ /storage libero per pool ZFS"
info ""
info "Comandi utili:"
info "  zramctl                           - Mostra dispositivi zram attivi"
info "  swapon --show                     - Mostra swap attivo (incluso zram)"
info "  df -h | grep zram                 - Mostra filesystem zram"
info "  systemctl status 'systemd-zram*'  - Stato servizi zram"
info ""
info "Per modificare la configurazione:"
info "  1. sudo nano /etc/systemd/zram-generator.conf"
info "  2. sudo systemctl daemon-reload"
info "  3. sudo reboot  # Per applicare modifiche"
echo ""

info "Installazione systemd-zram-generator completata con successo!"

