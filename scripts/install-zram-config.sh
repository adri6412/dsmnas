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
# systemd-zram-generator è un generatore systemd, verifica il pacchetto
if dpkg -l | grep -q "^ii.*systemd-zram-generator" && [ -f /etc/systemd/zram-generator.conf ]; then
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
# systemd-zram-generator è un generatore systemd, non un comando eseguibile
# Il file generatore si chiama "zram-generator" (senza systemd- davanti)
if dpkg -l | grep -q "^ii.*systemd-zram-generator"; then
    info "✓ Pacchetto systemd-zram-generator installato"
    
    # Verifica che il file generatore esista
    if [ -f /usr/lib/systemd/system-generators/zram-generator ] || \
       [ -f /lib/systemd/system-generators/zram-generator ]; then
        info "✓ Generatore zram trovato"
    else
        warn "Generatore non trovato nei percorsi standard, ma pacchetto installato"
    fi
else
    error "Pacchetto systemd-zram-generator non installato"
    error "Verifica con: dpkg -l | grep zram"
    exit 1
fi

# Rileva RAM disponibile
info "Rilevamento RAM disponibile..."
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$((TOTAL_RAM_KB / 1024 / 1024))

info "RAM totale rilevata: ${TOTAL_RAM_GB}GB"

# Calcola dimensioni zram in base alla RAM
# - Swap: 25% della RAM totale (min 2GB, max 16GB)
# - Log: 512MB-1GB (sufficiente per la maggior parte dei casi)
# - Tmp: 2-4GB (file temporanei)
# - Cache: 2-4GB (per apt cache e simili)

if [ $TOTAL_RAM_GB -ge 64 ]; then
    # Sistema con 64GB+ RAM
    SWAP_SIZE=16384
    LOG_SIZE=2048
    TMP_SIZE=4096
    CACHE_SIZE=4096
elif [ $TOTAL_RAM_GB -ge 32 ]; then
    # Sistema con 32-63GB RAM
    SWAP_SIZE=8192
    LOG_SIZE=1024
    TMP_SIZE=4096
    CACHE_SIZE=2048
elif [ $TOTAL_RAM_GB -ge 16 ]; then
    # Sistema con 16-31GB RAM
    SWAP_SIZE=4096
    LOG_SIZE=512
    TMP_SIZE=2048
    CACHE_SIZE=2048
else
    # Sistema con meno di 16GB RAM
    SWAP_SIZE=2048
    LOG_SIZE=256
    TMP_SIZE=1024
    CACHE_SIZE=1024
fi

info "Configurazione zram ottimizzata:"
info "  - Swap: ${SWAP_SIZE}MB"
info "  - Log: ${LOG_SIZE}MB"
info "  - Tmp: ${TMP_SIZE}MB"
info "  - Cache: ${CACHE_SIZE}MB"
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
fs-type = ext4
mount-point = /var/log

# /tmp in RAM compressa
[zram2]
zram-size = ${TMP_SIZE}
compression-algorithm = zstd
fs-type = ext4
mount-point = /tmp

# /var/cache in RAM compressa (per apt e altri cache)
[zram3]
zram-size = ${CACHE_SIZE}
compression-algorithm = zstd
fs-type = ext4
mount-point = /var/cache
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

# Esegui generatore manualmente per creare subito i dispositivi (senza riavvio)
# Il generatore si chiama "zram-generator" e può essere in /usr/lib o /lib
GENERATOR_PATH=""
if [ -x /usr/lib/systemd/system-generators/zram-generator ]; then
    GENERATOR_PATH="/usr/lib/systemd/system-generators/zram-generator"
elif [ -x /lib/systemd/system-generators/zram-generator ]; then
    GENERATOR_PATH="/lib/systemd/system-generators/zram-generator"
fi

if [ -n "$GENERATOR_PATH" ]; then
    info "Esecuzione generatore: $GENERATOR_PATH"
    "$GENERATOR_PATH" /run/systemd/generator /run/systemd/generator.early /run/systemd/generator.late 2>&1 || {
        warn "Generazione dispositivi fallita, riavvio necessario"
    }
    
    # Attiva i servizi generati
    for service in /run/systemd/generator/systemd-zram-setup@*.service; do
        if [ -f "$service" ]; then
            SERVICE_NAME=$(basename "$service")
            systemctl start "$SERVICE_NAME" 2>/dev/null || {
                warn "Impossibile avviare $SERVICE_NAME ora, funzionerà dopo il riavvio"
            }
        fi
    done
else
    warn "Generatore non trovato, i dispositivi saranno creati al prossimo riavvio"
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

