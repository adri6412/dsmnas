#!/bin/bash
# Script per creare pacchetto .run che disabilita snapshot automatiche ZFS
# Per utenti che hanno già il sistema installato

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Verifica makeself
if ! command -v makeself &> /dev/null; then
    error "makeself non trovato. Installalo con: sudo apt-get install makeself"
fi

# Directory di lavoro
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/disable-zfs-snapshots-build"
OUTPUT_DIR="$SCRIPT_DIR/updates"

# Versione
VERSION="disable_snapshots_v1.0"

info "Creazione pacchetto di aggiornamento: $VERSION"

# Pulizia build precedente
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
mkdir -p "$OUTPUT_DIR"

# Copia lo script di disabilitazione
cp "$SCRIPT_DIR/../scripts/disable-zfs-auto-snapshot.sh" "$BUILD_DIR/"

# Crea script di installazione per il pacchetto .run
cat > "$BUILD_DIR/install.sh" << 'EOF'
#!/bin/bash
# Script di installazione per disabilitazione snapshot ZFS

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

# Verifica root
if [ "$EUID" -ne 0 ]; then
    error "Questo aggiornamento deve essere eseguito come root"
fi

echo "=========================================="
echo "  ArmNAS - Disabilitazione Snapshot ZFS"
echo "=========================================="
echo ""
warn "Questo aggiornamento disabilita le snapshot automatiche ZFS"
warn "per evitare blocchi del sistema quando DSM è in VM"
echo ""

# Trova la directory di installazione
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Esegui lo script di disabilitazione
if [ -f "$SCRIPT_DIR/disable-zfs-auto-snapshot.sh" ]; then
    chmod +x "$SCRIPT_DIR/disable-zfs-auto-snapshot.sh"
    bash "$SCRIPT_DIR/disable-zfs-auto-snapshot.sh"
else
    error "Script disable-zfs-auto-snapshot.sh non trovato"
fi

echo ""
info "=========================================="
info "  ✅ Aggiornamento completato"
info "=========================================="
echo ""
info "Cosa è stato fatto:"
echo "  - Snapshot automatiche ZFS disabilitate"
echo "  - Servizi zfs-auto-snapshot fermati"
echo "  - Cron jobs snapshot rimossi"
echo "  - Documentazione creata in /opt/armnas/ZFS_SNAPSHOT_INFO.txt"
echo ""
warn "IMPORTANTE:"
echo "  - Le snapshot MANUALI ZFS continuano a funzionare"
echo "  - Le snapshot DSM interne NON sono influenzate"
echo "  - DSM continua a funzionare normalmente"
echo ""
info "Nessun riavvio richiesto"
echo ""

# Crea file di log aggiornamento
mkdir -p /var/lib/armnas/updates
echo "Update: disable-zfs-snapshots v1.0" > /var/lib/armnas/updates/disable-snapshots-applied.log
echo "Date: $(date -Iseconds)" >> /var/lib/armnas/updates/disable-snapshots-applied.log
echo "Status: SUCCESS" >> /var/lib/armnas/updates/disable-snapshots-applied.log

exit 0
EOF

chmod +x "$BUILD_DIR/install.sh"
chmod +x "$BUILD_DIR/disable-zfs-auto-snapshot.sh"

# Crea README per il pacchetto
cat > "$BUILD_DIR/README.txt" << 'EOF'
========================================
ArmNAS - Disabilitazione Snapshot ZFS
========================================

DESCRIZIONE:
------------
Questo aggiornamento disabilita le snapshot automatiche ZFS per evitare
blocchi del sistema quando DSM (Synology) è in esecuzione come VM.

PROBLEMA RISOLTO:
-----------------
Sistema si blocca periodicamente quando partono snapshot ZFS automatiche.

COSA FA QUESTO AGGIORNAMENTO:
------------------------------
1. Disabilita zfs-auto-snapshot (se installato)
2. Ferma tutti i servizi di snapshot automatiche
3. Rimuove cron jobs per snapshot ZFS
4. Disabilita sanoid/syncoid/pyznap se presenti
5. Crea documentazione utente

COSA NON FA:
------------
- NON rimuove snapshot esistenti
- NON disabilita snapshot manuali
- NON influenza le snapshot DSM interne
- NON richiede riavvio

INSTALLAZIONE:
--------------
sudo ./armnas_disable_snapshots_v1.0.run

VERIFICA:
---------
Dopo l'installazione, verifica con:
  systemctl list-timers | grep snapshot
  cat /opt/armnas/ZFS_SNAPSHOT_INFO.txt

ROLLBACK:
---------
Se vuoi riabilitare le snapshot automatiche (NON RACCOMANDATO con DSM):
  sudo apt-get install zfs-auto-snapshot
  sudo systemctl enable --now zfs-auto-snapshot-*.timer

SUPPORTO:
---------
https://github.com/tuo-progetto/armnas/issues
EOF

# Crea il pacchetto .run con makeself
info "Generazione pacchetto self-extracting..."

PACKAGE_NAME="armnas_disable_snapshots_v1.0"
OUTPUT_FILE="$OUTPUT_DIR/${PACKAGE_NAME}.run"

makeself \
    --notemp \
    --nomd5 \
    --sha256 \
    "$BUILD_DIR" \
    "$OUTPUT_FILE" \
    "ArmNAS - Disabilitazione Snapshot ZFS v1.0" \
    ./install.sh

if [ -f "$OUTPUT_FILE" ]; then
    info "✅ Pacchetto creato: $OUTPUT_FILE"
    
    # Crea file .info con metadati
    cat > "${OUTPUT_FILE}.info" << INFOEOF
{
  "version": "disable_snapshots_v1.0",
  "name": "Disabilitazione Snapshot ZFS",
  "description": "Disabilita snapshot automatiche ZFS per evitare blocchi sistema con DSM in VM",
  "date": "$(date -Iseconds)",
  "size": $(stat -f%z "$OUTPUT_FILE" 2>/dev/null || stat -c%s "$OUTPUT_FILE"),
  "checksum": "$(sha256sum "$OUTPUT_FILE" | awk '{print $1}')",
  "requires_reboot": false,
  "critical": true,
  "changelog": [
    "Disabilita zfs-auto-snapshot",
    "Rimuove cron jobs snapshot",
    "Disabilita servizi snapshot automatiche",
    "Previene blocchi sistema durante snapshot"
  ]
}
INFOEOF
    
    info "✅ Metadati creati: ${OUTPUT_FILE}.info"
    
    # Mostra info
    echo ""
    echo "=========================================="
    echo "  Pacchetto Pronto"
    echo "=========================================="
    echo ""
    info "File: $OUTPUT_FILE"
    info "Dimensione: $(du -h "$OUTPUT_FILE" | cut -f1)"
    info "SHA256: $(sha256sum "$OUTPUT_FILE" | awk '{print $1}')"
    echo ""
    info "Per testare l'installazione:"
    echo "  sudo $OUTPUT_FILE"
    echo ""
    info "Per distribuire l'aggiornamento:"
    echo "  1. Copia $OUTPUT_FILE sul server"
    echo "  2. Copia ${OUTPUT_FILE}.info sul server"
    echo "  3. Gli utenti riceveranno notifica di aggiornamento disponibile"
    echo ""
else
    error "Errore nella creazione del pacchetto"
fi

# Pulizia
info "Pulizia file temporanei..."
rm -rf "$BUILD_DIR"

info "✅ Completato!"

