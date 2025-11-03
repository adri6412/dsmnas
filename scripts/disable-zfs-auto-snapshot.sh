#!/bin/bash
# Script per disabilitare snapshot automatiche ZFS
# Le snapshot automatiche possono causare blocchi del sistema quando DSM è in VM

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica se eseguito come root
if [ "$EUID" -ne 0 ]; then 
    error "Questo script deve essere eseguito come root"
    exit 1
fi

info "Disabilitazione snapshot automatiche ZFS..."
echo "Motivo: Le snapshot automatiche possono bloccare il sistema quando DSM è in VM"

CHANGES_MADE=false

# 1. Disabilita zfs-auto-snapshot se installato
if command -v zfs-auto-snapshot &> /dev/null; then
    warn "zfs-auto-snapshot trovato, disabilitazione..."
    
    # Disabilita tutti i servizi systemd
    for service in $(systemctl list-unit-files | grep "zfs-auto-snapshot" | awk '{print $1}'); do
        if systemctl is-enabled "$service" 2>/dev/null | grep -q "enabled"; then
            info "  Disabilitazione servizio: $service"
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            CHANGES_MADE=true
        fi
    done
    
    # Rimuovi cron jobs
    if [ -d "/etc/cron.d" ]; then
        for cronfile in /etc/cron.d/*zfs-auto-snapshot* 2>/dev/null; do
            if [ -f "$cronfile" ]; then
                info "  Rimozione cron job: $cronfile"
                rm -f "$cronfile"
                CHANGES_MADE=true
            fi
        done
    fi
    
    # Disabilita negli altri cron
    for crondir in /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        if [ -d "$crondir" ]; then
            for cronfile in "$crondir"/*zfs-auto-snapshot* 2>/dev/null; do
                if [ -f "$cronfile" ]; then
                    info "  Rimozione: $cronfile"
                    rm -f "$cronfile"
                    CHANGES_MADE=true
                fi
            done
        fi
    done
else
    info "✓ zfs-auto-snapshot non installato"
fi

# 2. Cerca e disabilita altri cron jobs ZFS snapshot personalizzati
info "Ricerca cron jobs snapshot personalizzati..."
if grep -r "zfs snapshot" /etc/cron* 2>/dev/null | grep -v ".dpkg-" > /tmp/zfs-snapshot-crons.txt; then
    if [ -s /tmp/zfs-snapshot-crons.txt ]; then
        warn "Trovati cron jobs snapshot personalizzati:"
        cat /tmp/zfs-snapshot-crons.txt
        
        # Commenta le righe nei crontab
        while IFS=: read -r file line; do
            if [ -f "$file" ] && [ ! -L "$file" ]; then
                info "  Disabilitazione in: $file"
                sed -i '/zfs snapshot/s/^/# DISABLED by armnas: /' "$file" 2>/dev/null || true
                CHANGES_MADE=true
            fi
        done < /tmp/zfs-snapshot-crons.txt
    fi
fi
rm -f /tmp/zfs-snapshot-crons.txt

# 3. Disabilita sanoid/syncoid se installati
if command -v sanoid &> /dev/null; then
    warn "sanoid trovato, disabilitazione..."
    
    # Disabilita servizi sanoid
    for service in sanoid.service sanoid.timer syncoid.service syncoid.timer; do
        if systemctl list-unit-files | grep -q "^$service"; then
            info "  Disabilitazione: $service"
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            CHANGES_MADE=true
        fi
    done
fi

# 4. Disabilita pyznap se installato
if command -v pyznap &> /dev/null; then
    warn "pyznap trovato, disabilitazione..."
    
    # Disabilita servizi pyznap
    for service in pyznap.service pyznap.timer; do
        if systemctl list-unit-files | grep -q "^$service"; then
            info "  Disabilitazione: $service"
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            CHANGES_MADE=true
        fi
    done
fi

# 5. Controlla systemd timers per snapshot
info "Controllo systemd timers..."
SNAPSHOT_TIMERS=$(systemctl list-timers --all 2>/dev/null | grep -i "snapshot\|zfs" | grep -v "grep" || true)
if [ -n "$SNAPSHOT_TIMERS" ]; then
    warn "Timer snapshot attivi trovati:"
    echo "$SNAPSHOT_TIMERS"
    warn "Considera di disabilitarli manualmente se causano problemi"
fi

# 6. Crea file marker per indicare che le snapshot automatiche sono disabilitate
mkdir -p /var/lib/armnas
echo "ZFS automatic snapshots disabled on $(date -Iseconds)" > /var/lib/armnas/zfs-auto-snapshot-disabled
echo "Reason: Prevents system freeze when DSM is running in VM" >> /var/lib/armnas/zfs-auto-snapshot-disabled

# 7. Crea documentazione per l'utente
cat > /opt/armnas/ZFS_SNAPSHOT_INFO.txt << 'EOF'
========================================
  ZFS Snapshot - Informazioni Importanti
========================================

Le snapshot AUTOMATICHE di ZFS sono state DISABILITATE.

MOTIVO:
-------
Quando DSM (Synology) gira come VM, le snapshot automatiche ZFS dell'host
possono causare blocchi completi del sistema durante l'esecuzione.

COSA SIGNIFICA:
---------------
- ZFS snapshot automatiche: DISABILITATE
- ZFS snapshot manuali: FUNZIONANO normalmente
- DSM snapshot interne: NON SONO INFLUENZATE

SNAPSHOT MANUALI:
-----------------
Puoi creare snapshot ZFS manualmente quando necessario:

  # Crea snapshot manuale
  sudo zfs snapshot pool/dataset@nome_snapshot
  
  # Lista snapshot
  sudo zfs list -t snapshot
  
  # Elimina snapshot
  sudo zfs destroy pool/dataset@nome_snapshot

SNAPSHOT DSM:
-------------
DSM ha il proprio sistema di snapshot interno che continua a funzionare
normalmente. Usa l'interfaccia DSM per gestire le snapshot DSM.

IMPORTANTE:
-----------
NON riattivare le snapshot automatiche ZFS (zfs-auto-snapshot, sanoid, etc.)
se DSM è in esecuzione, per evitare blocchi del sistema.

Se hai bisogno di snapshot automatiche per i dati, usa invece:
- Snapshot DSM (gestite da Synology)
- Backup programmati DSM
- Hyper Backup di DSM

Per maggiori informazioni:
https://github.com/tuo-progetto/armnas/wiki/zfs-snapshots
EOF

chmod 644 /opt/armnas/ZFS_SNAPSHOT_INFO.txt
info "✓ Documentazione creata: /opt/armnas/ZFS_SNAPSHOT_INFO.txt"

# Ricarica systemd
systemctl daemon-reload 2>/dev/null || true

if [ "$CHANGES_MADE" = true ]; then
    info "✅ Snapshot automatiche ZFS disabilitate con successo"
    info "   Le snapshot manuali continuano a funzionare normalmente"
    info "   Documentazione: /opt/armnas/ZFS_SNAPSHOT_INFO.txt"
else
    info "✓ Nessuna snapshot automatica trovata da disabilitare"
fi

exit 0

