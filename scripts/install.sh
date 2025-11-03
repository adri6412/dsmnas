#!/bin/bash

# Script di installazione per ArmNAS
# Questo script installa tutte le dipendenze necessarie, configura il sistema
# e imposta un proxy Nginx per servire il frontend e reindirizzare le richieste API al backend

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi informativi
info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Funzione per stampare avvisi
warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Funzione per stampare errori
error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Funzione per verificare se un comando è disponibile
check_command() {
    if ! command -v $1 &> /dev/null; then
        error "Il comando $1 non è disponibile. Installazione in corso..."
        return 1
    else
        return 0
    fi
}

# Verifica se lo script è eseguito come root
if [ "$EUID" -ne 0 ]; then
    error "Questo script deve essere eseguito come root"
    exit 1
fi

# Directory di installazione
INSTALL_DIR="/opt/armnas"
BACKEND_DIR="$INSTALL_DIR/backend"
FRONTEND_DIR="$INSTALL_DIR/frontend"

# Trova la directory root del repository
# Lo script può essere eseguito da:
# 1. scripts/install.sh (quando estratto da makeself)
# 2. Dalla root del progetto (se eseguito manualmente)
# 3. Da qualsiasi directory (fallback)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "Script trovato in: $SCRIPT_DIR"

# Controlla se lo script è nella root (ha backend/ e frontend/ nella stessa directory)
if [ -d "$SCRIPT_DIR/backend" ] && [ -d "$SCRIPT_DIR/frontend" ]; then
    # Lo script è nella root del progetto
    REPO_DIR="$SCRIPT_DIR"
    info "Script eseguito dalla root del progetto"
# Controlla se lo script è in scripts/ (ha backend/ e frontend/ nel parent)
elif [ -d "$SCRIPT_DIR/../backend" ] && [ -d "$SCRIPT_DIR/../frontend" ]; then
    # Lo script è in scripts/, la root è il parent
    REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
    info "Script eseguito da scripts/, root trovata: $REPO_DIR"
else
    # Fallback: usa pwd (directory corrente)
    REPO_DIR=$(pwd)
    info "Tentativo con directory corrente: $REPO_DIR"
    if [ ! -d "$REPO_DIR/backend" ] || [ ! -d "$REPO_DIR/frontend" ]; then
        error "Impossibile trovare la directory root del progetto"
        error "Script directory: $SCRIPT_DIR"
        error "Current directory: $REPO_DIR"
        error ""
        error "Struttura attesa:"
        error "  nas/"
        error "  ├── backend/"
        error "  ├── frontend/"
        error "  └── scripts/"
        error "      └── install.sh"
        error ""
        error "Assicurati che:"
        error "  1. Makeself estragga correttamente tutta la struttura"
        error "  2. Lo script sia eseguito dalla directory estratta"
        exit 1
    fi
fi

info "Directory repository root: $REPO_DIR"
info "Verifica struttura:"
info "  ✓ backend/: $([ -d "$REPO_DIR/backend" ] && echo 'OK' || echo 'MANCANTE')"
info "  ✓ frontend/: $([ -d "$REPO_DIR/frontend" ] && echo 'OK' || echo 'MANCANTE')"
info "  ✓ scripts/: $([ -d "$REPO_DIR/scripts" ] && echo 'OK' || echo 'MANCANTE')"
info "  ✓ config/: $([ -d "$REPO_DIR/config" ] && echo 'OK' || echo 'MANCANTE')"

# Funzione per assicurarsi che /opt/armnas sia sempre scrivibile (rw)
# NOTA: Con zram-config, non usiamo più overlayfs sul root filesystem
# Questa funzione verifica solo che la directory sia scrivibile
ensure_armnas_rw() {
    info "Verifica che /opt/armnas sia scrivibile (usando zram-config, non overlayfs)..."
    
    # Con zram-config, il root filesystem rimane scrivibile normalmente
    # Solo swap e log vanno in RAM compressa, non il root filesystem
    
    local OVERLAY_ACTIVE=false
    local LOWER_ROOT=""
    
    # Verifica comunque se overlayroot è attivo (per compatibilità con vecchie installazioni)
    if [ -d "/media/root-ro" ] && mountpoint -q "/media/root-ro" 2>/dev/null; then
        OVERLAY_ACTIVE=true
        LOWER_ROOT="/media/root-ro"
        warn "ATTENZIONE: overlayroot attivo (lower root: $LOWER_ROOT)"
        warn "Questo sistema usa ancora overlayfs invece di zram-config"
        warn "Considera di disabilitare overlayfs e usare solo zram-config"
    # Verifica se ci sono mount overlay attivi sul root filesystem
    elif mount | grep -q "on /.*type overlay"; then
        OVERLAY_ACTIVE=true
        warn "Questo sistema usa ancora overlayfs invece di zram-config"
    fi
    
    # Con zram-config, il root filesystem è sempre scrivibile normalmente
    # Verifica solo che /opt/armnas esista e sia scrivibile
    if [ "$OVERLAY_ACTIVE" = "false" ]; then
        info "✅ Sistema configurato correttamente: nessun overlayfs, usando zram-config"
        info "   Root filesystem scrivibile normalmente, swap/log in RAM compressa"
    fi
    
    # Crea e verifica la directory /opt/armnas
    mkdir -p "$INSTALL_DIR" 2>/dev/null || {
        error "Impossibile creare $INSTALL_DIR"
        exit 1
    }
    
    # Verifica che sia scrivibile
    if touch "$INSTALL_DIR/.rw_test" 2>/dev/null; then
        rm -f "$INSTALL_DIR/.rw_test"
        info "✓ $INSTALL_DIR è scrivibile"
    else
        error "ERRORE: $INSTALL_DIR NON è scrivibile!"
        error "Verifica i permessi e lo spazio disponibile"
        exit 1
    fi
}

# Assicura che /opt/armnas sia sempre scrivibile (rw) PRIMA di creare le directory
info "Verifica e configurazione /opt/armnas per essere sempre scrivibile..."
ensure_armnas_rw

# Crea le directory di installazione
info "Creazione delle directory di installazione..."
mkdir -p $BACKEND_DIR
mkdir -p $FRONTEND_DIR

# Aggiorna il sistema
info "Aggiornamento del sistema..."
apt-get update
apt-get upgrade -y

# Rimuovi pacchetti specifici per Raspberry Pi se installati (non necessari su amd64)
if dpkg -l | grep -q "^ii.*raspi-firmware"; then
    info "Rimozione pacchetto raspi-firmware (non necessario su amd64)..."
    # Rimuovi lo script problematico prima della rimozione
    rm -f /etc/initramfs/post-update.d/z50-raspi-firmware 2>/dev/null || true
    apt-get remove -y raspi-firmware || true
    # Completa la configurazione di initramfs-tools se necessario
    dpkg --configure -a || true
    apt-get autoremove -y || true
fi

# Installa le dipendenze di sistema
info "Installazione delle dipendenze di sistema..."
apt-get install -y python3 python3-pip python3-venv python3-dev nodejs npm nginx samba vsftpd openssh-server smartmontools ntfs-3g libffi-dev libssl-dev build-essential zfsutils-linux qemu-kvm

# Installa Docker
info "Installazione di Docker..."
if ! command -v docker &> /dev/null; then
    # Installazione Docker usando lo script ufficiale
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    
    # Avvia Docker e configura l'avvio automatico
    systemctl enable docker
    systemctl start docker
else
    info "Docker è già installato"
fi

# Installa Docker Compose se non è disponibile
info "Verifica Docker Compose..."
if ! docker compose version &> /dev/null; then
    if ! docker-compose --version &> /dev/null; then
        info "Installazione Docker Compose..."
        apt-get install -y docker-compose-plugin
    fi
else
    info "Docker Compose è già disponibile"
fi

# Assicurati che i servizi siano installati correttamente
info "Verifica dell'installazione dei servizi..."
if ! dpkg -l | grep -q "samba"; then
    warn "Samba non sembra essere installato correttamente. Reinstallazione..."
    apt-get install --reinstall -y samba
fi

if ! dpkg -l | grep -q "vsftpd"; then
    warn "vsftpd non sembra essere installato correttamente. Reinstallazione..."
    apt-get install --reinstall -y vsftpd
fi

# Configura il backend
info "Configurazione del backend..."
python3 -m venv $BACKEND_DIR/venv
source $BACKEND_DIR/venv/bin/activate
pip install --upgrade pip
pip install wheel
pip install -r $REPO_DIR/backend/requirements.txt

# Copia i file del backend
info "Copia dei file del backend..."
cp -r $REPO_DIR/backend/* $BACKEND_DIR/

# Copia lo script di correzione dei permessi
cp $REPO_DIR/scripts/fix_permissions.sh $INSTALL_DIR/

# Copia docker-compose.yml se esiste
if [ -f "$REPO_DIR/config/docker-compose.yml" ]; then
    info "Copia docker-compose.yml..."
    cp $REPO_DIR/config/docker-compose.yml $INSTALL_DIR/
fi

# Crea directory per virtual-dsm storage
info "Creazione directory per virtual-dsm..."
mkdir -p $INSTALL_DIR/virtual-dsm-storage
chmod 755 $INSTALL_DIR/virtual-dsm-storage

# Configura il frontend
info "Configurazione del frontend..."
cd $REPO_DIR/frontend
npm install
NODE_OPTIONS=--openssl-legacy-provider npm run build

# Copia i file del frontend
info "Copia dei file del frontend..."
cp -r $REPO_DIR/frontend/dist/* $FRONTEND_DIR/

# Crea il servizio systemd per il backend
info "Creazione del servizio systemd per il backend..."
cat > /etc/systemd/system/armnas-backend.service << EOF
[Unit]
Description=ArmNAS Backend Service
After=network.target

[Service]
User=root
WorkingDirectory=$BACKEND_DIR
ExecStart=$BACKEND_DIR/venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Crea il servizio systemd per l'updater (servizio separato per aggiornamenti)
info "Creazione del servizio systemd per l'updater..."
cat > /etc/systemd/system/armnas-updater.service << EOF
[Unit]
Description=ArmNAS Update Service (Separate)
After=network.target
PartOf=armnas-backend.service

[Service]
User=root
WorkingDirectory=$BACKEND_DIR
ExecStart=$BACKEND_DIR/venv/bin/python3 $BACKEND_DIR/updater_service.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Configura Nginx
info "Configurazione di Nginx..."
cat > /etc/nginx/sites-available/armnas << EOF
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;

    # Aumenta il buffer per evitare errori 413
    client_max_body_size 100M;

    # Servire i file statici del frontend
    location / {
        root $FRONTEND_DIR;
        index index.html;
        try_files \$uri \$uri/ /index.html;
    }

    # Reindirizzare le richieste API al backend
    location /api/ {
        proxy_pass http://127.0.0.1:8000/api/;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 90;
        proxy_connect_timeout 90;
        proxy_buffering off;
    }
}
EOF

# Abilita il sito Nginx
ln -sf /etc/nginx/sites-available/armnas /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default

# Verifica la configurazione di Nginx
nginx -t

# Configura Samba
info "Configurazione di Samba..."
if [ ! -f /etc/samba/smb.conf.bak ]; then
    cp /etc/samba/smb.conf /etc/samba/smb.conf.bak
fi

cat > /etc/samba/smb.conf << EOF
[global]
   workgroup = WORKGROUP
   server string = ArmNAS
   server role = standalone server
   log file = /var/log/samba/log.%m
   max log size = 1000
   logging = file
   panic action = /usr/share/samba/panic-action %d
   server role = standalone server
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *Enter\snew\s*\spassword:* %n\n *Retype\snew\s*\spassword:* %n\n *password\supdated\ssuccessfully* .
   pam password change = yes
   map to guest = bad user
   usershare allow guests = yes

[NAS]
   path = /mnt/nas_data
   browseable = yes
   writable = yes
   guest ok = no
   read only = no
   create mask = 0775
   directory mask = 0775
EOF

# Configura vsftpd
info "Configurazione di vsftpd..."
if [ ! -f /etc/vsftpd.conf.bak ]; then
    cp /etc/vsftpd.conf /etc/vsftpd.conf.bak
fi

cat > /etc/vsftpd.conf << EOF
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
chroot_local_user=YES
secure_chroot_dir=/var/run/vsftpd/empty
pam_service_name=vsftpd
rsa_cert_file=/etc/ssl/certs/ssl-cert-snakeoil.pem
rsa_private_key_file=/etc/ssl/private/ssl-cert-snakeoil.key
ssl_enable=NO
EOF

# Configura SSH per SFTP
info "Configurazione di SSH per SFTP..."
if ! grep -q "Subsystem sftp internal-sftp" /etc/ssh/sshd_config; then
    # Backup del file di configurazione SSH
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
    
    # Rimuovi eventuali configurazioni Subsystem sftp esistenti
    sed -i '/Subsystem\s\+sftp/d' /etc/ssh/sshd_config
    
    # Aggiungi la nuova configurazione SFTP
    cat >> /etc/ssh/sshd_config << EOF

# SFTP configuration
Subsystem sftp internal-sftp

Match Group sftponly
    ChrootDirectory %h
    ForceCommand internal-sftp
    AllowTcpForwarding no
    X11Forwarding no
EOF
fi

# Crea il gruppo sftponly se non esiste
if ! getent group sftponly > /dev/null; then
    groupadd sftponly
fi

# Crea la directory per i dati del NAS
info "Creazione della directory per i dati del NAS..."
mkdir -p /mnt/nas_data
chmod 755 /mnt/nas_data
chown -R armnas:armnas /mnt/nas_data

# Avvia e abilita i servizi
info "Avvio e abilitazione dei servizi..."
systemctl daemon-reload
systemctl enable armnas-backend
systemctl enable armnas-updater
systemctl enable nginx
systemctl enable smbd
systemctl enable vsftpd
systemctl enable ssh

# Crea un utente di test per Samba
info "Creazione dell'utente di test per Samba..."
useradd -m -s /bin/bash armnas
echo "armnas:armnas" | chpasswd
smbpasswd -a armnas -n
echo -e "armnas\narmnas" | smbpasswd -s -a armnas

# Assicurati che i servizi siano avviati
systemctl restart smbd
systemctl restart vsftpd
systemctl restart ssh
systemctl restart nginx
systemctl restart armnas-backend
systemctl restart armnas-updater

# Crea uno script di avvio automatico per il montaggio del disco
info "Creazione dello script di montaggio automatico..."
cat > /etc/udev/rules.d/99-armnas-mount.rules << EOF
ACTION=="add", KERNEL=="sd[a-z][0-9]", RUN+="/bin/mkdir -p /mnt/nas_data", RUN+="/bin/mount /dev/%k /mnt/nas_data"
EOF

# Configura zram-config per proteggere la scheda SD dalle scritture eccessive
info "Configurazione zram-config per ridurre scritture su SD..."
info "Riferimento: https://github.com/ecdye/zram-config"

# Installa zram-config usando lo script dedicato
if [ -f "$REPO_DIR/scripts/install-zram-config.sh" ]; then
    info "Esecuzione script di installazione zram-config..."
    bash "$REPO_DIR/scripts/install-zram-config.sh"
else
    error "Script install-zram-config.sh non trovato in $REPO_DIR/scripts/"
    exit 1
fi

# Applica branding Virtual DSM Bare Metal
info "Applicazione branding Virtual DSM Bare Metal..."
if [ -f "$REPO_DIR/scripts/branding-vdsm.sh" ]; then
    bash "$REPO_DIR/scripts/branding-vdsm.sh"
    info "✓ Branding applicato"
else
    warn "Script branding-vdsm.sh non trovato, branding saltato"
fi

# NOTA: Non configurare overlayfs - usiamo zram-config invece!
# overlayfs è stato sostituito da zram-config per una migliore protezione della SD card
# e migliori performance (scritture compresse in RAM invece che overlay complesso)

# Il resto della configurazione overlayfs è stato rimosso - ora si usa zram-config
# Se necessario in futuro, la configurazione overlayfs può essere aggiunta manualmente

# Saltiamo la configurazione overlayfs precedente
if false; then
# Codice overlayfs rimosso - mantenuto solo per riferimento storico
cat > /usr/local/bin/setup-overlayfs.sh << 'OVERLAYEOF'
#!/bin/bash
# Script per configurare overlayfs al boot
# Questo script monta overlayfs su / per ridurre le scritture sulla SD

set -e

OVERLAY_UPPER="/overlay/upper"
OVERLAY_WORK="/overlay/work"
OVERLAY_MOUNT="/overlay/root"

# Crea directory se non esistono
mkdir -p "$OVERLAY_UPPER"
mkdir -p "$OVERLAY_WORK"
mkdir -p "$OVERLAY_MOUNT"

# Verifica se overlayfs è già montato
if mountpoint -q "$OVERLAY_MOUNT"; then
    echo "Overlayfs già montato"
    exit 0
fi

# Verifica che il kernel supporti overlay
if ! grep -q overlay /proc/filesystems; then
    echo "ERRORE: overlay filesystem non supportato dal kernel"
    exit 1
fi

# Monta overlayfs temporaneamente per verificare che funzioni
if ! mount -t overlay overlay -o lowerdir=/,upperdir="$OVERLAY_UPPER",workdir="$OVERLAY_WORK" "$OVERLAY_MOUNT" 2>/dev/null; then
    echo "ERRORE: Impossibile montare overlayfs"
    exit 1
fi

umount "$OVERLAY_MOUNT"
echo "Overlayfs configurato correttamente"
OVERLAYEOF

chmod +x /usr/local/bin/setup-overlayfs.sh

# Configura overlayfs usando initramfs (metodo più robusto)
# Installa overlayroot se disponibile (pacchetto Debian per overlayfs)
info "Installazione supporto overlayfs..."

# Prova a installare overlayroot (il pacchetto si chiama solo "overlayroot")
# È disponibile in Debian testing/unstable, ma non sempre in stable
OVERLAYROOT_INSTALLED=false

if apt-cache search overlayroot 2>/dev/null | grep -q "^overlayroot "; then
    info "Pacchetto overlayroot trovato nel repository, installazione..."
    if apt-get install -y overlayroot; then
        OVERLAYROOT_INSTALLED=true
        info "✓ overlayroot installato con successo"
    else
        warn "Installazione overlayroot fallita dal repository principale"
    fi
fi

# Se non disponibile nel repository principale, prova da testing (opzionale)
if [ "$OVERLAYROOT_INSTALLED" = "false" ]; then
    warn "overlayroot non disponibile nel repository stable."
    warn "Il sistema userà il metodo manuale per overlayfs."
    warn ""
    warn "Se vuoi installare overlayroot da testing (opzionale, rischioso):"
    warn "  echo 'deb http://deb.debian.org/debian testing main' > /etc/apt/sources.list.d/testing.list"
    warn "  apt-get update && apt-get install -t testing overlayroot"
fi

# Sistema RO/RW per overlayfs: default scrive su RAM, con comando rw scrive su SD
info "Configurazione sistema RO/RW per overlayfs (default: RAM, rw: SD card)..."

# Crea directory per overlay persistente sulla SD
mkdir -p /overlay/upper-sd
mkdir -p /overlay/work-sd

# Crea script per gestire modalità RO/RW
cat > /usr/local/bin/overlay-rw << 'OVERLAYRWEOF'
#!/bin/bash
# Script per passare overlayfs da modalità RO (RAM) a RW (SD card) SENZA RIAVVIO
# Sincronizza le modifiche dalla RAM alla SD e cambia l'upper directory sulla SD
# Gestisce anche /storage e pool ZFS per permettere scritture persistenti

set -e

OVERLAY_UPPER="/overlay/upper"
OVERLAY_WORK="/overlay/work"
OVERLAY_UPPER_SD="/overlay/upper-sd"
OVERLAY_WORK_SD="/overlay/work-sd"
OVERLAY_STATE="/var/lib/overlay-state"

# Funzione per gestire /storage e pool ZFS
handle_storage_rw() {
    echo "🗄️  Gestione /storage per modalità RW..."
    
    # 1. Verifica se /storage è montato
    if mountpoint -q /storage 2>/dev/null; then
        echo "   /storage è montato, verifica tipo..."
        
        # Verifica se è un mount overlay/tmpfs che blocca ZFS
        STORAGE_FSTYPE=$(findmnt -n -o FSTYPE /storage 2>/dev/null || echo "unknown")
        STORAGE_SOURCE=$(findmnt -n -o SOURCE /storage 2>/dev/null || echo "unknown")
        
        if [ "$STORAGE_FSTYPE" = "overlay" ] || [ "$STORAGE_FSTYPE" = "tmpfs" ] || echo "$STORAGE_SOURCE" | grep -q "overlay\|tmpfs"; then
            echo "   /storage è montato come $STORAGE_FSTYPE (overlay/tmpfs)"
            echo "   Smontaggio per permettere accesso diretto a ZFS..."
            
            # Esporta pool ZFS se esistono
            if command -v zpool >/dev/null 2>&1; then
                if zpool list storage 2>/dev/null | grep -q "storage"; then
                    echo "   Esportazione pool ZFS 'storage'..."
                    zpool export storage 2>/dev/null || true
                fi
            fi
            
            # Smonta /storage
            umount /storage 2>/dev/null || umount -l /storage 2>/dev/null || true
            echo "   ✓ /storage smontato"
        elif [ "$STORAGE_FSTYPE" = "zfs" ]; then
            echo "   ✓ /storage già montato come ZFS (niente da fare)"
            return 0
        else
            echo "   ℹ️  /storage montato come $STORAGE_FSTYPE"
        fi
    fi
    
    # 2. Se overlayfs è attivo, monta /storage dalla SD originale
    if [ -n "$LOWER_ROOT" ] && [ -d "$LOWER_ROOT" ]; then
        if [ -d "$LOWER_ROOT/storage" ]; then
            echo "   Montaggio /storage dalla SD originale ($LOWER_ROOT/storage)..."
            mkdir -p /storage
            
            # Smonta prima se necessario
            mountpoint -q /storage 2>/dev/null && umount /storage 2>/dev/null || true
            
            # Monta dalla SD originale con bind mount
            if mount --bind "$LOWER_ROOT/storage" /storage 2>/dev/null; then
                echo "   ✓ /storage montato dalla SD originale (RW diretto)"
            else
                echo "   ⚠️  Impossibile montare /storage dalla SD, sarà disponibile normalmente"
            fi
        fi
    fi
    
    # 3. Importa pool ZFS se esistono
    if command -v zpool >/dev/null 2>&1; then
        # Verifica se ci sono pool da importare
        if zpool import 2>/dev/null | grep -q "pool: storage"; then
            echo "   Pool ZFS 'storage' disponibile per importazione..."
            if zpool import storage 2>/dev/null; then
                echo "   ✓ Pool ZFS 'storage' importato"
            else
                echo "   ℹ️  Pool ZFS non importato (potrebbe non esistere o essere già montato)"
            fi
        fi
    fi
    
    echo "   ✓ Gestione /storage completata"
}

# Trova il lower root (SD originale)
LOWER_ROOT=""
if [ -d "/media/root-ro" ] && mountpoint -q "/media/root-ro" 2>/dev/null; then
    LOWER_ROOT="/media/root-ro"
elif mount | grep -q "type overlay.*on /"; then
    # Estrai lowerdir dall'overlay montato
    OVERLAY_INFO=$(mount | grep "type overlay.*on /" | head -1)
    if echo "$OVERLAY_INFO" | grep -q "lowerdir="; then
        LOWER_ROOT=$(echo "$OVERLAY_INFO" | grep -oP 'lowerdir=\K[^,]+' | head -1)
    fi
fi

if [ -z "$LOWER_ROOT" ] || [ ! -d "$LOWER_ROOT" ]; then
    # Se non troviamo il lower root, potrebbe non essere overlayfs attivo
    # In questo caso, il sistema è già in RW
    echo "⚠️ Overlayfs non attivo - sistema già in modalità RW (scritture dirette su SD)"
    mkdir -p "$(dirname $OVERLAY_STATE)"
    echo "rw" > "$OVERLAY_STATE"
    
    # Gestisci comunque /storage per liberarlo da eventuali mount overlay residui
    handle_storage_rw
    exit 0
fi

echo "🔄 Passaggio a modalità RW (scrittura su SD card) - senza riavvio..."

# Se siamo già in modalità RW, verifica e sincronizza se necessario
if [ -f "$OVERLAY_STATE" ] && [ "$(cat $OVERLAY_STATE 2>/dev/null)" = "rw" ]; then
    # Verifica se upper è già sulla SD
    if mountpoint -q "$OVERLAY_UPPER" 2>/dev/null; then
        UPPER_SOURCE=$(findmnt -n -o SOURCE "$OVERLAY_UPPER" 2>/dev/null || echo "")
        if [ -n "$UPPER_SOURCE" ] && echo "$UPPER_SOURCE" | grep -q "$LOWER_ROOT\|upper-sd"; then
            echo "✓ Sistema già in modalità RW (upper directory sulla SD)"
            # Gestisci /storage anche se già in RW
            handle_storage_rw
            exit 0
        fi
    fi
fi

# Crea directory SD se non esistono
mkdir -p "$OVERLAY_UPPER_SD"
mkdir -p "$OVERLAY_WORK_SD"

# Se l'upper è in tmpfs (RAM), sincronizza le modifiche alla SD
if mountpoint -q "$OVERLAY_UPPER" 2>/dev/null; then
    UPPER_SOURCE=$(findmnt -n -o SOURCE "$OVERLAY_UPPER" 2>/dev/null || echo "")
    if [ -n "$UPPER_SOURCE" ] && echo "$UPPER_SOURCE" | grep -q "tmpfs"; then
        echo "📦 Sincronizzazione modifiche dalla RAM alla SD..."
        
        # Sincronizza il contenuto (rsync o cp con preservazione)
        if command -v rsync &> /dev/null; then
            rsync -a "$OVERLAY_UPPER/" "$OVERLAY_UPPER_SD/" 2>/dev/null || true
        else
            cp -a "$OVERLAY_UPPER"/* "$OVERLAY_UPPER_SD/" 2>/dev/null || true
        fi
        
        echo "✓ Modifiche sincronizzate dalla RAM alla SD"
        
        # Sincronizza i filesystem prima del rimontaggio
        sync
        
        # Rimonta upper directory sulla SD usando bind mount
        echo "🔄 Rimontaggio upper directory sulla SD..."
        umount "$OVERLAY_UPPER" 2>/dev/null || true
        mount --bind "$OVERLAY_UPPER_SD" "$OVERLAY_UPPER" || {
            echo "✗ Errore nel rimontare upper directory sulla SD"
            # Riprova a montare tmpfs in caso di errore
            mount -t tmpfs -o size=512M,mode=0755 tmpfs "$OVERLAY_UPPER" 2>/dev/null || true
            exit 1
        }
        echo "✓ Upper directory rimontata sulla SD"
    fi
else
    # Se upper non è montato, montalo sulla SD
    echo "🔄 Montaggio upper directory sulla SD..."
    mount --bind "$OVERLAY_UPPER_SD" "$OVERLAY_UPPER" 2>/dev/null || {
        # Se fallisce, monta tmpfs come fallback
        mount -t tmpfs -o size=512M,mode=0755 tmpfs "$OVERLAY_UPPER" 2>/dev/null || true
    }
fi

# Gestisci /storage per modalità RW
handle_storage_rw

# Salva stato RW
mkdir -p "$(dirname $OVERLAY_STATE)"
echo "rw" > "$OVERLAY_STATE"

# Aggiorna anche overlayroot.conf per prossimi avvii
if [ -f "/etc/overlayroot.conf" ]; then
    echo "overlayroot=\"\"" > /etc/overlayroot.conf
fi

echo ""
echo "✅ Sistema ora in modalità RW - le scritture vanno sulla SD card"
echo "   /storage è ora accessibile per pool ZFS"
echo "   Nessun riavvio necessario!"
OVERLAYRWEOF

chmod +x /usr/local/bin/overlay-rw

cat > /usr/local/bin/overlay-ro << 'OVERLAYROEOF'
#!/bin/bash
# Script per passare overlayfs da modalità RW (SD) a RO (RAM) SENZA RIAVVIO
# Torna a scrivere solo in RAM, le modifiche non vengono salvate sulla SD
# Gestisce anche /storage e pool ZFS

set -e

OVERLAY_UPPER="/overlay/upper"
OVERLAY_WORK="/overlay/work"
OVERLAY_UPPER_SD="/overlay/upper-sd"
OVERLAY_STATE="/var/lib/overlay-state"

# Funzione per gestire /storage per modalità RO
handle_storage_ro() {
    echo "🗄️  Gestione /storage per modalità RO..."
    
    # 1. Esporta pool ZFS se esistono (per evitare conflitti)
    if command -v zpool >/dev/null 2>&1; then
        if zpool list storage 2>/dev/null | grep -q "storage"; then
            echo "   Pool ZFS 'storage' trovato, esportazione..."
            zpool export storage 2>/dev/null || {
                echo "   ⚠️  Impossibile esportare pool ZFS (potrebbe essere in uso)"
                echo "   Prova a chiudere applicazioni che usano /storage"
            }
        fi
    fi
    
    # 2. Smonta /storage se montato
    if mountpoint -q /storage 2>/dev/null; then
        echo "   Smontaggio /storage..."
        umount /storage 2>/dev/null || umount -l /storage 2>/dev/null || {
            echo "   ⚠️  Impossibile smontare /storage (potrebbe essere in uso)"
        }
    fi
    
    # 3. In modalità RO, /storage sarà gestito dall'overlay
    #    Le modifiche a /storage andranno solo in RAM
    echo "   ℹ️  In modalità RO, le modifiche a /storage vanno in RAM (non persistenti)"
    echo "   ✓ Gestione /storage completata"
}

# Trova il lower root (SD originale)
LOWER_ROOT=""
if [ -d "/media/root-ro" ] && mountpoint -q "/media/root-ro" 2>/dev/null; then
    LOWER_ROOT="/media/root-ro"
elif mount | grep -q "type overlay.*on /"; then
    OVERLAY_INFO=$(mount | grep "type overlay.*on /" | head -1)
    if echo "$OVERLAY_INFO" | grep -q "lowerdir="; then
        LOWER_ROOT=$(echo "$OVERLAY_INFO" | grep -oP 'lowerdir=\K[^,]+' | head -1)
    fi
fi

if [ -z "$LOWER_ROOT" ] || [ ! -d "$LOWER_ROOT" ]; then
    # Se non troviamo il lower root, overlayfs non è attivo
    echo "⚠️ Overlayfs non attivo - sistema già in modalità normale"
    mkdir -p "$(dirname $OVERLAY_STATE)"
    echo "ro" > "$OVERLAY_STATE"
    
    # Gestisci comunque /storage
    handle_storage_ro
    exit 0
fi

echo "🔄 Passaggio a modalità RO (scrittura in RAM) - senza riavvio..."

# Se siamo già in modalità RO, verifica
if [ -f "$OVERLAY_STATE" ] && [ "$(cat $OVERLAY_STATE 2>/dev/null)" = "ro" ]; then
    if mountpoint -q "$OVERLAY_UPPER" 2>/dev/null; then
        UPPER_SOURCE=$(findmnt -n -o SOURCE "$OVERLAY_UPPER" 2>/dev/null || echo "")
        if [ -n "$UPPER_SOURCE" ] && echo "$UPPER_SOURCE" | grep -q "tmpfs"; then
            echo "✓ Sistema già in modalità RO (upper directory in RAM/tmpfs)"
            # Gestisci /storage anche se già in RO
            handle_storage_ro
            exit 0
        fi
    fi
fi

# Gestisci /storage prima di modificare l'overlay
handle_storage_ro

# Se l'upper è sulla SD, sincronizza le modifiche e rimonta in RAM
if mountpoint -q "$OVERLAY_UPPER" 2>/dev/null; then
    UPPER_SOURCE=$(findmnt -n -o SOURCE "$OVERLAY_UPPER" 2>/dev/null || echo "")
    if [ -n "$UPPER_SOURCE" ] && echo "$UPPER_SOURCE" | grep -q "$LOWER_ROOT\|upper-sd"; then
        echo "📦 Sincronizzazione ultime modifiche dalla SD alla RAM..."
        
        # Sincronizza i filesystem prima del rimontaggio
        sync
        
        echo "🔄 Rimontaggio upper directory in RAM (tmpfs)..."
        umount "$OVERLAY_UPPER" 2>/dev/null || true
        
        # Rimonta come tmpfs (RAM)
        mount -t tmpfs -o size=512M,mode=0755 tmpfs "$OVERLAY_UPPER" || {
            echo "✗ Errore nel rimontare upper directory in RAM"
            exit 1
        }
        echo "✓ Upper directory rimontata in RAM (tmpfs)"
    else
        # Già in tmpfs, niente da fare
        echo "✓ Upper directory già in RAM (tmpfs)"
    fi
else
    # Se upper non è montato, montalo in RAM
    echo "🔄 Montaggio upper directory in RAM (tmpfs)..."
    mount -t tmpfs -o size=512M,mode=0755 tmpfs "$OVERLAY_UPPER" 2>/dev/null || {
        echo "✗ Errore nel montare upper directory in RAM"
        exit 1
    }
fi

# Salva stato RO
mkdir -p "$(dirname $OVERLAY_STATE)"
echo "ro" > "$OVERLAY_STATE"

# Aggiorna anche overlayroot.conf per prossimi avvii
if [ -f "/etc/overlayroot.conf" ]; then
    echo "overlayroot=\"tmpfs:swap=1,recurse=0\"" > /etc/overlayroot.conf
fi

echo ""
echo "✅ Sistema ora in modalità RO - le scritture vanno in RAM (temporanee)"
echo "   /storage non è disponibile per pool ZFS in modalità RO"
echo "   Usa 'overlay-rw' per tornare in modalità RW e usare ZFS"
echo "   Nessun riavvio necessario!"
echo "   Le modifiche non verranno salvate permanentemente sulla SD."
OVERLAYROEOF

chmod +x /usr/local/bin/overlay-ro

# Crea comando per verificare lo stato
cat > /usr/local/bin/overlay-status << 'STATUSEOF'
#!/bin/bash
# Verifica lo stato corrente del sistema overlayfs (RO o RW)

OVERLAY_STATE="/var/lib/overlay-state"
OVERLAYROOT_CONF="/etc/overlayroot.conf"

echo "📊 Stato Overlayfs:"
echo ""

# Verifica stato salvato
if [ -f "$OVERLAY_STATE" ]; then
    MODE=$(cat "$OVERLAY_STATE" 2>/dev/null || echo "ro")
    if [ "$MODE" = "rw" ]; then
        echo "  Modalità configurata: RW (scritture su SD card)"
    else
        echo "  Modalità configurata: RO (scritture in RAM)"
    fi
else
    echo "  Modalità configurata: RO (default, scritture in RAM)"
fi

# Verifica configurazione overlayroot
if [ -f "$OVERLAYROOT_CONF" ]; then
    if grep -q 'overlayroot=""' "$OVERLAYROOT_CONF"; then
        echo "  Overlayroot: DISABILITATO (scritture dirette su SD)"
    elif grep -q 'overlayroot="tmpfs' "$OVERLAYROOT_CONF"; then
        echo "  Overlayroot: ABILITATO con tmpfs (scritture in RAM)"
    else
        echo "  Overlayroot: Configurazione personalizzata"
        grep "^overlayroot=" "$OVERLAYROOT_CONF" | head -1
    fi
fi

# Verifica se overlayfs è attivo
echo ""
if mount | grep -q "on /.*type overlay"; then
    echo "  ✅ Overlayfs ATTIVO"
    mount | grep "type overlay" | head -1
else
    echo "  ⚠️  Overlayfs NON ATTIVO (sistema in modalità normale)"
fi

echo ""
echo "Comandi disponibili:"
echo "  ro           - Passa a modalità RO (RAM) - SENZA riavvio"
echo "  rw           - Passa a modalità RW (SD) - SENZA riavvio"
echo "  overlay-status - Mostra questo stato"
STATUSEOF

chmod +x /usr/local/bin/overlay-status

# Crea alias comodi ro/rw
cat > /etc/profile.d/overlay-ro-rw.sh << 'ALIASEOF'
# Alias per controllo overlayfs ro/rw
alias ro='overlay-ro'
alias rw='overlay-rw'
alias overlay-status='overlay-status'
ALIASEOF

chmod +x /etc/profile.d/overlay-ro-rw.sh

# Crea script per configurare overlayroot basato sullo stato
# Questo script legge lo stato e configura overlayroot di conseguenza
cat > /usr/local/bin/configure-overlay-mode.sh << 'CONFIGOVERLAYEOF'
#!/bin/bash
# Configura overlayroot in base allo stato RO/RW
# Questo script viene eseguito all'avvio prima di overlayroot

OVERLAY_STATE="/var/lib/overlay-state"
OVERLAYROOT_CONF="/etc/overlayroot.conf"
LOWER_ROOT="/media/root-ro"

# Se non esiste file di stato, default è RO (RAM)
if [ ! -f "$OVERLAY_STATE" ]; then
    mkdir -p "$(dirname $OVERLAY_STATE)"
    echo "ro" > "$OVERLAY_STATE"
fi

MODE=$(cat "$OVERLAY_STATE" 2>/dev/null || echo "ro")

if [ "$MODE" = "rw" ]; then
    # Modalità RW: disabilita overlayroot per scrivere direttamente sulla SD
    echo "overlayroot=\"\"" > "$OVERLAYROOT_CONF"
    
    # Sincronizza le modifiche dalla RAM (se esistono) alla SD
    if [ -d "$LOWER_ROOT" ] && [ -d "/overlay/upper-sd" ]; then
        if [ -d "/tmp/overlay-upper-ram" ]; then
            # C'era un overlay RAM, sincronizzalo
            rsync -a "/tmp/overlay-upper-ram/" "/overlay/upper-sd/" 2>/dev/null || true
        fi
    fi
else
    # Modalità RO: scrivi in RAM (tmpfs)
    echo "overlayroot=\"tmpfs:swap=1,recurse=0\"" > "$OVERLAYROOT_CONF"
fi
CONFIGOVERLAYEOF

chmod +x /usr/local/bin/configure-overlay-mode.sh

# Lo script configure-overlay-mode.sh viene mantenuto per compatibilità
# ma non viene più usato come servizio systemd (overlayroot viene configurato prima dell'avvio)

# Se overlayroot è installato, configura per usare tmpfs di default
if [ "$OVERLAYROOT_INSTALLED" = "true" ] && command -v overlayroot-chroot &> /dev/null; then
    info "Configurazione overlayroot con sistema RO/RW..."
    
    # Configura overlayroot per usare tmpfs (RAM) di default
    cat > /etc/overlayroot.conf << 'OVERLAYROOTEOF'
overlayroot="tmpfs:swap=1,recurse=0"
OVERLAYROOTEOF
    
    # Crea hook per configurare la modalità prima di overlayroot
    mkdir -p /etc/initramfs-tools/hooks
    cat > /etc/initramfs-tools/hooks/configure-overlay-mode << 'HOOKEOF'
#!/bin/sh
PREREQ=""
prereqs() {
    echo "$PREREQ"
}
case $1 in
prereqs)
    prereqs
    exit 0
    ;;
esac

# Copia lo script di configurazione nell'initramfs
if [ -f /usr/local/bin/configure-overlay-mode.sh ]; then
    . /usr/local/bin/configure-overlay-mode.sh
fi
HOOKEOF
    
    chmod +x /etc/initramfs-tools/hooks/configure-overlay-mode
    
    info "✓ Overlayroot configurato con sistema RO/RW"
    info "  Default: RO (scritture in RAM)"
    info "  Comando 'rw': passa a RW (scritture su SD) - SENZA riavvio"
    info "  Comando 'ro': passa a RO (scritture in RAM) - SENZA riavvio"
    info "  Comando 'overlay-status': mostra lo stato corrente"
else
    # Metodo alternativo: configura overlayfs manualmente via fstab
    warn "overlayroot non disponibile, configurando overlayfs manualmente..."
    
    # Backup fstab originale
    if [ ! -f /etc/fstab.orig ]; then
        cp /etc/fstab /etc/fstab.orig
    fi
    
    # Crea uno script systemd per montare overlayfs
    cat > /etc/systemd/system/overlayfs.service << 'SERVICEEOF'
[Unit]
Description=Mount OverlayFS on Root
DefaultDependencies=no
Before=local-fs.target umount.target
After=systemd-remount-fs.service
Conflicts=umount.target
RequiresMountsFor=/overlay

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/mount-overlayfs.sh
StandardOutput=journal+console

[Install]
RequiredBy=local-fs.target
SERVICEEOF

    # Crea script di montaggio overlayfs
    cat > /usr/local/bin/mount-overlayfs.sh << 'MOUNTOVERLAYEOF'
#!/bin/bash
# Monta overlayfs su root per proteggere SD card

set -e

OVERLAY_UPPER="/overlay/upper"
OVERLAY_WORK="/overlay/work"
OVERLAY_ROOT="/overlay/root"

mkdir -p "$OVERLAY_UPPER" "$OVERLAY_WORK" "$OVERLAY_ROOT"

# Usa tmpfs per upper e work directory (RAM)
if ! mountpoint -q "$OVERLAY_UPPER"; then
    mount -t tmpfs -o size=512M,mode=0755 tmpfs "$OVERLAY_UPPER"
fi

if ! mountpoint -q "$OVERLAY_WORK"; then
    mount -t tmpfs -o size=128M,mode=0755 tmpfs "$OVERLAY_WORK"
fi

# Monta overlayfs (nota: questo è complesso da fare su root già montato)
# Per questo motivo, consigliamo di usare overlayroot se disponibile
echo "Overlayfs preparato. Per applicarlo su root, è necessario configurare initramfs."
MOUNTOVERLAYEOF

    chmod +x /usr/local/bin/mount-overlayfs.sh
    
    systemctl enable overlayfs.service 2>/dev/null || warn "Impossibile abilitare servizio overlayfs"
    
    info "Script overlayfs creato. NOTA: Per applicare overlayfs su root filesystem,"
    info "è necessario modificare initramfs. Questo richiede un riavvio e può essere complesso."
    info "Si consiglia di usare overlayroot se disponibile nel repository."
fi

# Assicurati che /storage e directory importanti non siano in overlay
info "Configurazione directory persistenti..."
# Crea symlink per directory che devono essere persistenti
# Nota: /storage è già su ZFS pool, quindi è persistente di default

# Se Docker non usa /storage, assicurati che /var/lib/docker sia persistente
if [ ! -L /var/lib/docker ]; then
    # Docker può essere configurato per usare /storage/docker
    mkdir -p /storage/docker 2>/dev/null || true
fi

info "Overlayfs configurato. Le scritture su root filesystem saranno temporanee."
warn "IMPORTANTE: Le modifiche permanenti devono essere fatte in modalità non-overlay o"
warn "salvate manualmente. Si consiglia di usare overlayroot per una gestione automatica."

# Configurazione SEMPRE attiva: /opt/armnas deve essere sempre scrivibile sulla SD
# Crea script per escludere /opt/armnas e /storage dall'overlay usando bind mount
# Questo script funziona sia con overlayroot che con overlayfs generico
info "Configurazione bind mount per /opt/armnas (sempre scrivibile sulla SD)..."
cat > /usr/local/bin/bind-armnas.sh << 'BINDEOF'
#!/bin/bash
# Script per montare /opt/armnas e /storage dalla SD originale, escludendoli dall'overlay
# Questo permette al software e a ZFS di scrivere permanentemente sulla SD
# Funziona sia con overlayroot che con overlayfs generico

set -e

# Funzione per trovare il lower root (SD originale)
find_lower_root() {
    local LOWER_ROOT=""
    
    # 1. Prova con overlayroot (crea /media/root-ro)
    if [ -d "/media/root-ro" ] && mountpoint -q "/media/root-ro" 2>/dev/null; then
        LOWER_ROOT="/media/root-ro"
        echo "Trovato lower root (overlayroot): $LOWER_ROOT"
        echo "$LOWER_ROOT"
        return 0
    fi
    
    # 2. Prova percorsi comuni per overlayfs generico
    if [ -d "/overlay/root" ] && mountpoint -q "/overlay/root" 2>/dev/null; then
        LOWER_ROOT="/overlay/root"
        echo "Trovato lower root (overlayfs): $LOWER_ROOT"
        echo "$LOWER_ROOT"
        return 0
    fi
    
    # 3. Usa findmnt per trovare il lower directory da overlayfs
    if command -v findmnt &> /dev/null; then
        local LOWER_INFO=$(findmnt -M / -n -o OPTIONS 2>/dev/null)
        if [ -n "$LOWER_INFO" ] && echo "$LOWER_INFO" | grep -q "lowerdir="; then
            # Estrai il primo lowerdir (potrebbe esserci grep -P o sed)
            if echo "$LOWER_INFO" | grep -oP 'lowerdir=\K[^,]+' 2>/dev/null | head -1 | read LOWER_ROOT; then
                if [ -n "$LOWER_ROOT" ] && [ -d "$LOWER_ROOT" ]; then
                    echo "Trovato lower root (findmnt): $LOWER_ROOT"
                    echo "$LOWER_ROOT"
                    return 0
                fi
            fi
            # Fallback con sed se grep -P non è disponibile
            LOWER_ROOT=$(echo "$LOWER_INFO" | sed -n 's/.*lowerdir=\([^,]*\).*/\1/p' | head -1)
            if [ -n "$LOWER_ROOT" ] && [ -d "$LOWER_ROOT" ]; then
                echo "Trovato lower root (findmnt+sed): $LOWER_ROOT"
                echo "$LOWER_ROOT"
                return 0
            fi
        fi
    fi
    
    # 4. Se non troviamo un lower root, overlayfs potrebbe non essere attivo
    # In questo caso, non facciamo nulla (il filesystem è già scrivibile)
    echo ""
    return 1
}

# Funzione per montare una directory dalla SD originale
mount_from_sd() {
    local TARGET_DIR="$1"
    local LOWER_ROOT="$2"
    
    # Se non abbiamo un lower root, overlayfs non è attivo - non serve montare
    if [ -z "$LOWER_ROOT" ]; then
        echo "⚠️ Overlayfs non attivo - $TARGET_DIR è già scrivibile"
        return 0
    fi
    
    local LOWER_DIR="$LOWER_ROOT$TARGET_DIR"
    
    # Verifica che il lower root esista
    if [ ! -d "$LOWER_ROOT" ]; then
        echo "⚠️ Lower root non trovato: $LOWER_ROOT"
        return 0
    fi
    
    # Crea la directory nell'overlay se non esiste
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
    fi
    
    # Se non è già montato, monta la directory dalla SD originale
    if ! mountpoint -q "$TARGET_DIR" 2>/dev/null; then
        # Crea la directory nella SD originale se non esiste
        if [ ! -d "$LOWER_DIR" ]; then
            # Prova a rendere il lower root scrivibile se è in ro
            if mount | grep -q "$LOWER_ROOT.*ro,"; then
                mount -o remount,rw "$LOWER_ROOT" 2>/dev/null || true
            fi
            mkdir -p "$LOWER_DIR" 2>/dev/null || {
                echo "⚠️ Impossibile creare $LOWER_DIR nella SD originale"
                return 1
            }
        fi
        
        # Monta dalla SD originale
        if mount --bind "$LOWER_DIR" "$TARGET_DIR" 2>/dev/null; then
            echo "✓ Montato $LOWER_DIR su $TARGET_DIR (sempre scrivibile dalla SD)"
        else
            echo "✗ Errore nel montare $LOWER_DIR su $TARGET_DIR"
            return 1
        fi
    else
        # Verifica che sia montato dalla SD originale
        local MOUNT_SOURCE=$(findmnt -n -o SOURCE "$TARGET_DIR" 2>/dev/null || echo "")
        if [ -n "$MOUNT_SOURCE" ] && echo "$MOUNT_SOURCE" | grep -q "$LOWER_ROOT"; then
            echo "✓ $TARGET_DIR già montato dalla SD originale (scrivable)"
        else
            echo "⚠️ $TARGET_DIR montato da: $MOUNT_SOURCE (potrebbe non essere dalla SD)"
        fi
    fi
}

# Trova il lower root
LOWER_ROOT=$(find_lower_root)

# Monta /opt/armnas (sempre dalla SD originale se overlayfs è attivo)
mount_from_sd "/opt/armnas" "$LOWER_ROOT"

# Monta /storage (escluso dall'overlay per permettere a ZFS di funzionare correttamente)
# /storage è dove vengono montati i pool ZFS, quindi deve essere sul filesystem reale
mount_from_sd "/storage" "$LOWER_ROOT"

echo "✓ Directory persistenti configurate"
BINDEOF

chmod +x /usr/local/bin/bind-armnas.sh

# Crea servizio systemd per eseguire lo script all'avvio
# IMPORTANTE: Questo servizio deve essere eseguito PRIMA di ZFS e armnas-backend
# per permettere a ZFS di montare correttamente i pool su /storage
# e al backend di scrivere in /opt/armnas
info "Creazione servizio systemd per bind mount permanente..."
cat > /etc/systemd/system/bind-armnas.service << 'SERVICEEOF'
[Unit]
Description=Bind mount /opt/armnas and /storage from SD (always writable, exclude from overlay)
After=local-fs.target
Before=zfs-mount.service zfs-import-cache.service armnas-backend.service
Wants=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/bind-armnas.sh
StandardOutput=journal+console
StandardError=journal+console
# Non fallire se overlayfs non è attivo
ExecStartPre=/bin/true

[Install]
WantedBy=multi-user.target
SERVICEEOF

# Se overlayroot è installato, aggiungi la dipendenza opzionale
if [ "$OVERLAYROOT_INSTALLED" = "true" ]; then
    # Aggiungi dipendenza da overlayroot.service
    sed -i '/^After=local-fs.target$/a After=overlayroot.service\nWants=overlayroot.service' /etc/systemd/system/bind-armnas.service 2>/dev/null || {
        # Fallback: riscrivi il file con la dipendenza
        cat > /etc/systemd/system/bind-armnas.service << 'SERVICEEOF'
[Unit]
Description=Bind mount /opt/armnas and /storage from SD (always writable, exclude from overlay)
After=local-fs.target overlayroot.service
Before=zfs-mount.service zfs-import-cache.service armnas-backend.service
Wants=overlayroot.service local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/bind-armnas.sh
StandardOutput=journal+console
StandardError=journal+console
# Non fallire se overlayfs non è attivo
ExecStartPre=/bin/true

[Install]
WantedBy=multi-user.target
SERVICEEOF
    }
fi

# Abilita e avvia il servizio
systemctl daemon-reload
systemctl enable bind-armnas.service

# Prova ad avviare il servizio ora (potrebbe fallire se overlayfs non è attivo, ma va bene)
if systemctl start bind-armnas.service 2>/dev/null; then
    info "✓ Servizio bind-armnas avviato con successo"
else
    warn "Servizio bind-armnas non avviato (normale se overlayfs non è attivo)"
fi

info "/opt/armnas e /storage saranno sempre scrivibili sulla SD, anche con overlayfs attivo."
info "Il servizio bind-armnas.service si avvia automaticamente all'avvio del sistema."
fi  # Fine blocco if false - codice overlayfs disabilitato

info "✅ Sistema configurato per usare zram-config invece di overlayfs"
info "   - Swap compresso in RAM (riduce scritture su SD)"
info "   - Log in RAM compressa (/var/log)"
info "   - /storage disponibile per pool ZFS"
info "   - Nessun overlay sul root filesystem"

# Ottieni l'indirizzo IP
IP_ADDRESS=$(hostname -I | awk '{print $1}')

# Correggi i permessi
info "Correzione dei permessi..."
chmod +x $REPO_DIR/scripts/fix_permissions.sh
chmod +x $REPO_DIR/scripts/fix_nginx.sh
chmod +x $REPO_DIR/scripts/fix_backend.sh
$REPO_DIR/scripts/fix_permissions.sh

# Copia gli script di correzione
cp $REPO_DIR/scripts/fix_nginx.sh $INSTALL_DIR/
cp $REPO_DIR/scripts/fix_backend.sh $INSTALL_DIR/

# Disabilita autologin e auto-esecuzione installer dopo installazione
info "Disabilitazione autologin e auto-esecuzione installer..."

# 1. Rimuovi autologin di root
if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
    rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
    info "✓ Autologin disabilitato"
fi

# 2. Rimuovi configurazione getty override se esiste
if [ -f /etc/systemd/system/getty@tty1.service.d/override.conf ]; then
    rm -f /etc/systemd/system/getty@tty1.service.d/override.conf
fi

# 3. Pulisci .profile di root dal codice di auto-esecuzione
if [ -f /root/.profile ]; then
    # Rimuovi tutte le righe relative a installer_dsm.sh e FLAG_FILE
    sed -i '/installer_dsm\.sh/d' /root/.profile 2>/dev/null || true
    sed -i '/FLAG_FILE/d' /root/.profile 2>/dev/null || true
    sed -i '/ARM NAS - Installazione Automatica/d' /root/.profile 2>/dev/null || true
    sed -i '/INSTALLER=/d' /root/.profile 2>/dev/null || true
    sed -i '/Installazione già completata/d' /root/.profile 2>/dev/null || true
    sed -i '/già completata/d' /root/.profile 2>/dev/null || true
    sed -i '/installer-completed/d' /root/.profile 2>/dev/null || true
    sed -i '/\/var\/lib\/armnas/d' /root/.profile 2>/dev/null || true
    sed -i '/rieseguire.*rm.*FLAG/d' /root/.profile 2>/dev/null || true
    
    # Rimuovi anche eventuali blocchi if-fi relativi al flag file
    # Questo è più aggressivo ma sicuro
    sed -i '/if \[ -f "\$FLAG_FILE" \]/,/^fi$/d' /root/.profile 2>/dev/null || true
    
    # Se .profile è quasi vuoto, ricrealo con versione standard
    if [ $(wc -l < /root/.profile 2>/dev/null || echo 0) -lt 5 ]; then
        cat > /root/.profile << 'PROFILEEOF'
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n 2> /dev/null || true
PROFILEEOF
    fi
    
    info "✓ Auto-esecuzione installer rimossa da .profile"
fi

# 4. Crea flag file per indicare installazione completata
mkdir -p /var/lib/armnas
echo "COMPLETED: $(date -Iseconds)" > /var/lib/armnas/installer-completed
echo "Installer: ARM NAS installation script" >> /var/lib/armnas/installer-completed
info "✓ Flag file installazione creato"

# 5. Ricarica configurazione systemd
systemctl daemon-reload 2>/dev/null || true

# 6. Disabilita eventuali servizi auto-install se esistono
if systemctl is-enabled auto-install-dsm.service 2>/dev/null; then
    systemctl disable auto-install-dsm.service 2>/dev/null || true
    info "✓ Servizio auto-install disabilitato"
fi

info "✓ Sistema configurato per login normale (richiederà password)"

# Leggi versione se disponibile
VERSION="unknown"
if [ -f "$INSTALL_DIR/VERSION" ]; then
    VERSION=$(cat "$INSTALL_DIR/VERSION" 2>/dev/null | tr -d '\n\r')
elif [ -f "$REPO_DIR/VERSION" ]; then
    VERSION=$(cat "$REPO_DIR/VERSION" 2>/dev/null | tr -d '\n\r')
fi

# Messaggio finale
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║                                                            ║"
echo "║         ✅ Installazione ArmNAS Completata! ✅             ║"
echo "║                                                            ║"
echo "║  Versione: v${VERSION}                                        ║"
echo "║                                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
info "Puoi accedere all'interfaccia web di ArmNAS all'indirizzo: http://$IP_ADDRESS"
info ""
info "Credenziali di accesso predefinite:"
info "  Username: admin"
info "  Password: admin"
echo ""
warn "⚠️  Si consiglia di cambiare la password predefinita dopo il primo accesso."
info "Se riscontri problemi, esegui gli script di correzione:"
info "  sudo $INSTALL_DIR/fix_permissions.sh  # Per correggere i permessi"
info "  sudo $INSTALL_DIR/fix_nginx.sh        # Per correggere la configurazione di Nginx"
info "  sudo $INSTALL_DIR/fix_backend.sh      # Per correggere e riavviare il backend"

exit 0