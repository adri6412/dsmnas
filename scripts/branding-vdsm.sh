#!/bin/bash
# Script per brandizzare il sistema come "Virtual DSM Bare Metal"
# Modifica GRUB, /etc/os-release, banner di login, e MOTD

set -e

# Colori
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

info "=== Branding Virtual DSM Bare Metal ==="
echo ""

# Nome del sistema
OS_NAME="Virtual DSM Bare Metal"
OS_ID="vdsm"
OS_VERSION="1.0"
OS_CODENAME="Synology-Like"

# 1. Backup file originali
info "Backup file originali..."
for file in /etc/os-release /etc/issue /etc/issue.net /etc/motd /etc/default/grub; do
    if [ -f "$file" ] && [ ! -f "${file}.orig" ]; then
        cp "$file" "${file}.orig"
        info "✓ Backup: ${file}.orig"
    fi
done

# 2. Modifica /etc/os-release
info "Configurazione /etc/os-release..."
cat > /etc/os-release << EOF
PRETTY_NAME="$OS_NAME $OS_VERSION"
NAME="$OS_NAME"
VERSION_ID="$OS_VERSION"
VERSION="$OS_VERSION ($OS_CODENAME)"
VERSION_CODENAME="$OS_CODENAME"
ID=$OS_ID
ID_LIKE=debian
HOME_URL="https://github.com/adri6412/dsmnas"
SUPPORT_URL="https://github.com/adri6412/dsmnas/issues"
BUG_REPORT_URL="https://github.com/adri6412/dsmnas/issues"
EOF
info "✓ /etc/os-release aggiornato"

# 3. Crea banner ASCII art per login
info "Creazione banner di login..."
cat > /etc/issue << 'EOF'

\033[1;34m╔══════════════════════════════════════════════════════════════╗\033[0m
\033[1;34m║                                                              ║\033[0m
\033[1;36m║        __      ___      _               _   ____  ____  __  ║\033[0m
\033[1;36m║        \ \    / (_)_ __| |_ _  _ __ _  | | |  _ \/ ___||  \/  |║\033[0m
\033[1;36m║         \ \  / /| | '__| __| | | |/ _` | | | | | |\___ \| |\/| |║\033[0m
\033[1;36m║          \ \/ / | | |  | |_| |_| | (_| | | | |_| | ___) | |  | |║\033[0m
\033[1;36m║           \__/  |_|_|   \__|\__,_|\__,_|_| |____/ |____/|_|  |_|║\033[0m
\033[1;34m║                                                              ║\033[0m
\033[1;32m║              Bare Metal Edition - Powered by ZFS             ║\033[0m
\033[1;34m║                                                              ║\033[0m
\033[1;34m╚══════════════════════════════════════════════════════════════╝\033[0m

\033[1;33m  System: $OS_NAME $OS_VERSION\033[0m
\033[0;37m  Kernel: \r (\l)\033[0m
\033[0;36m  https://github.com/adri6412/dsmnas\033[0m

EOF

# Copia per network login
cp /etc/issue /etc/issue.net
info "✓ Banner di login creato"

# 4. Crea MOTD (Message of the Day)
info "Creazione MOTD..."
cat > /etc/motd << 'EOF'

╔══════════════════════════════════════════════════════════════╗
║                   Virtual DSM Bare Metal                     ║
║                        Version 1.0                           ║
╚══════════════════════════════════════════════════════════════╝

🚀 Benvenuto nel tuo NAS Virtual DSM!

📊 Sistema:
   - ZFS per storage affidabile e snapshots
   - zram per ridurre usura SD/SSD (~80% scritture in meno)
   - Docker per applicazioni containerizzate
   - Nginx + FastAPI backend per gestione web

💡 Comandi utili:
   zpool status              - Stato pool ZFS
   zramctl                   - Stato dispositivi zram
   docker ps                 - Container attivi
   systemctl status armnas-backend - Stato backend

📚 Documentazione: /opt/armnas/docs/
🐛 Issues: https://github.com/adri6412/dsmnas/issues

EOF
info "✓ MOTD creato"

# 5. Modifica GRUB
info "Configurazione GRUB..."

# Backup grub config
if [ -f /etc/default/grub ]; then
    # Modifica distributore GRUB
    sed -i 's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Virtual DSM Bare Metal"/' /etc/default/grub
    
    # Se non esiste, aggiungi
    if ! grep -q "^GRUB_DISTRIBUTOR=" /etc/default/grub; then
        echo 'GRUB_DISTRIBUTOR="Virtual DSM Bare Metal"' >> /etc/default/grub
    fi
    
    # Aggiungi timeout se molto corto
    if grep -q "^GRUB_TIMEOUT=0" /etc/default/grub; then
        sed -i 's/^GRUB_TIMEOUT=0/GRUB_TIMEOUT=3/' /etc/default/grub
        info "✓ Timeout GRUB aumentato a 3 secondi"
    fi
    
    # Rigenera configurazione GRUB
    if command -v update-grub >/dev/null 2>&1; then
        info "Rigenerazione configurazione GRUB..."
        update-grub
        info "✓ GRUB aggiornato"
    elif command -v grub-mkconfig >/dev/null 2>&1; then
        info "Rigenerazione configurazione GRUB..."
        grub-mkconfig -o /boot/grub/grub.cfg
        info "✓ GRUB aggiornato"
    else
        warn "Comando update-grub non trovato, GRUB non aggiornato"
        warn "Esegui manualmente: sudo update-grub"
    fi
else
    warn "/etc/default/grub non trovato, GRUB non modificato"
fi

# 6. Crea script per mostrare info sistema
info "Creazione script di sistema..."
cat > /usr/local/bin/vdsm-info << 'VDSMEOF'
#!/bin/bash
# Mostra informazioni sul sistema Virtual DSM

# Colori
BLUE='\033[1;34m'
GREEN='\033[1;32m'
CYAN='\033[1;36m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║${CYAN}              Virtual DSM Bare Metal - System Info            ${BLUE}║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

# OS Info
echo -e "${GREEN}📋 Sistema Operativo:${NC}"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "   Nome: $PRETTY_NAME"
    echo "   Versione: $VERSION"
fi
echo "   Kernel: $(uname -r)"
echo "   Architettura: $(uname -m)"
echo ""

# Uptime
echo -e "${GREEN}⏰ Uptime:${NC}"
uptime -p
echo ""

# RAM
echo -e "${GREEN}💾 Memoria RAM:${NC}"
free -h | grep -E "^Mem:" | awk '{print "   Totale: "$2"  |  Usata: "$3"  |  Libera: "$4"  |  Disponibile: "$7}'
echo ""

# zram
echo -e "${GREEN}🗜️  Dispositivi zram:${NC}"
if command -v zramctl >/dev/null 2>&1; then
    zramctl --output NAME,DISKSIZE,DATA,COMPR,TOTAL,ALGORITHM,MOUNTPOINT 2>/dev/null | head -5
else
    echo "   zramctl non disponibile"
fi
echo ""

# ZFS
echo -e "${GREEN}💿 Pool ZFS:${NC}"
if command -v zpool >/dev/null 2>&1; then
    if zpool list 2>/dev/null | grep -q "storage"; then
        zpool list -H storage 2>/dev/null | awk '{print "   Storage: "$2" totale  |  "$3" usato  |  "$4" libero  |  "$8" salute"}'
    else
        echo "   Nessun pool ZFS configurato"
    fi
else
    echo "   ZFS non disponibile"
fi
echo ""

# Docker
echo -e "${GREEN}🐳 Container Docker:${NC}"
if command -v docker >/dev/null 2>&1; then
    RUNNING=$(docker ps -q 2>/dev/null | wc -l)
    TOTAL=$(docker ps -aq 2>/dev/null | wc -l)
    echo "   Running: $RUNNING / $TOTAL"
else
    echo "   Docker non disponibile"
fi
echo ""

# Servizi
echo -e "${GREEN}⚙️  Servizi ArmNAS:${NC}"
for service in armnas-backend nginx smbd vsftpd; do
    if systemctl is-active --quiet $service 2>/dev/null; then
        echo -e "   ${GREEN}✓${NC} $service: attivo"
    else
        echo -e "   ${YELLOW}✗${NC} $service: inattivo"
    fi
done
echo ""

# Storage montati
echo -e "${GREEN}📁 Storage:${NC}"
df -h | grep -E "^/dev/|^overlay|^/dev/zram" | awk '{print "   "$1" → "$6" ("$5" usato)"}'
echo ""

echo -e "${CYAN}💡 Comandi utili: vdsm-info, zpool status, zramctl, docker ps${NC}"
echo ""
VDSMEOF

chmod +x /usr/local/bin/vdsm-info
info "✓ Script vdsm-info creato"

# 7. Crea alias
info "Creazione alias..."
cat > /etc/profile.d/vdsm-aliases.sh << 'ALIASEOF'
# Alias per Virtual DSM Bare Metal
alias vdsm='vdsm-info'
alias sysinfo='vdsm-info'
alias dsm='vdsm-info'
ALIASEOF

chmod +x /etc/profile.d/vdsm-aliases.sh
info "✓ Alias creati (vdsm, sysinfo, dsm)"

# 8. Informazioni finali
echo ""
info "=== Branding Completato ==="
echo ""
info "✅ Sistema brandizzato come: $OS_NAME $OS_VERSION"
echo ""
info "Modifiche applicate:"
info "  ✓ /etc/os-release - Identità sistema"
info "  ✓ /etc/issue - Banner login console"
info "  ✓ /etc/motd - Message of the Day"
info "  ✓ GRUB - Menu di boot"
info "  ✓ vdsm-info - Script informazioni sistema"
echo ""
info "Comandi disponibili:"
info "  vdsm-info    - Mostra informazioni sistema"
info "  vdsm         - Alias per vdsm-info"
info "  sysinfo      - Alias per vdsm-info"
echo ""
warn "Per vedere il nuovo branding GRUB, riavvia il sistema:"
warn "  sudo reboot"
echo ""
info "File originali salvati con estensione .orig per ripristino"
echo ""

# Mostra preview
info "Preview banner:"
cat /etc/issue | sed 's/\\033\[/\x1b[/g' | sed 's/\\r//' | sed 's/\\l/tty1/'
echo ""

info "Branding completato con successo!"

