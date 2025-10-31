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
        proxy_pass http://localhost:8000/api/;
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

# Crea uno script di avvio automatico per il montaggio del disco
info "Creazione dello script di montaggio automatico..."
cat > /etc/udev/rules.d/99-armnas-mount.rules << EOF
ACTION=="add", KERNEL=="sd[a-z][0-9]", RUN+="/bin/mkdir -p /mnt/nas_data", RUN+="/bin/mount /dev/%k /mnt/nas_data"
EOF

# Configura overlayfs per proteggere la scheda SD dalle scritture eccessive
info "Configurazione overlayfs per proteggere la scheda SD..."
# Crea directory per overlayfs
mkdir -p /overlay/{upper,work}

# Crea script per configurare overlayfs all'avvio
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

# Se overlayroot è installato, configura per usare tmpfs
if [ "$OVERLAYROOT_INSTALLED" = "true" ] && command -v overlayroot-chroot &> /dev/null; then
    info "Configurazione overlayroot con tmpfs..."
    # Configura overlayroot per usare tmpfs (RAM)
    # IMPORTANTE: /storage deve essere escluso dall'overlay per permettere a ZFS di funzionare
    # overlayroot non supporta direttamente exclude, quindi useremo bind mount dopo
    cat > /etc/overlayroot.conf << 'OVERLAYROOTEOF'
overlayroot="tmpfs:swap=1,recurse=0"
OVERLAYROOTEOF
    
    # Crea anche un file per escludere directory specifiche (se supportato)
    # Nota: overlayroot non supporta nativamente exclude, quindi usiamo bind mount
    info "Configurazione esclusioni overlayroot (via bind mount)..."
    
    info "Overlayroot configurato. Il sistema userà tmpfs per le scritture."
    
    # Crea script per escludere /opt/armnas e /storage dall'overlay usando bind mount
    # Questo script viene eseguito dopo che overlayroot è attivo
    info "Configurazione bind mount per /opt/armnas e /storage (esclusi dall'overlay)..."
    cat > /usr/local/bin/bind-armnas.sh << 'BINDEOF'
#!/bin/bash
# Script per montare /opt/armnas e /storage dalla SD originale, escludendoli dall'overlay
# Questo permette al software e a ZFS di scrivere permanentemente sulla SD

set -e

# overlayroot crea un mount point per il lower filesystem in /media/root-ro
LOWER_ROOT="/media/root-ro"

# Funzione per montare una directory dalla SD originale
mount_from_sd() {
    local TARGET_DIR="$1"
    local LOWER_DIR="$LOWER_ROOT$TARGET_DIR"
    
    # Verifica che il lower root esista (overlayroot attivo)
    if [ ! -d "$LOWER_ROOT" ]; then
        echo "⚠️ Overlayroot non attivo (lower root non trovato)"
        return 0
    fi
    
    # Crea la directory nell'overlay se non esiste
    if [ ! -d "$TARGET_DIR" ]; then
        mkdir -p "$TARGET_DIR"
    fi
    
    # Se non è già montato, monta la directory dalla SD originale
    if ! mountpoint -q "$TARGET_DIR"; then
        # Crea la directory nella SD originale se non esiste
        if [ ! -d "$LOWER_DIR" ]; then
            mkdir -p "$LOWER_DIR"
        fi
        
        # Monta dalla SD originale
        mount --bind "$LOWER_DIR" "$TARGET_DIR"
        echo "✓ Montato $LOWER_DIR su $TARGET_DIR (escluso dall'overlay)"
    else
        echo "✓ $TARGET_DIR già montato"
    fi
}

# Monta /opt/armnas (escluso dall'overlay)
mount_from_sd "/opt/armnas"

# Monta /storage (escluso dall'overlay per permettere a ZFS di funzionare correttamente)
# /storage è dove vengono montati i pool ZFS, quindi deve essere sul filesystem reale
mount_from_sd "/storage"

echo "✓ Directory persistenti configurate"
BINDEOF

    chmod +x /usr/local/bin/bind-armnas.sh
    
    # Crea servizio systemd per eseguire lo script dopo overlayroot
    # IMPORTANTE: Questo servizio deve essere eseguito PRIMA di ZFS per permettere
    # a ZFS di montare correttamente i pool su /storage
    cat > /etc/systemd/system/bind-armnas.service << 'SERVICEEOF'
[Unit]
Description=Bind mount /opt/armnas and /storage from SD (exclude from overlay)
After=local-fs.target overlayroot.service
Before=zfs-mount.service zfs-import-cache.service armnas-backend.service
Wants=overlayroot.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/local/bin/bind-armnas.sh
StandardOutput=journal+console
StandardError=journal+console

[Install]
WantedBy=multi-user.target
SERVICEEOF

    systemctl enable bind-armnas.service
    
    info "/opt/armnas e /storage saranno esclusi dall'overlay e scriveranno direttamente sulla SD."
    info "Questo è necessario per permettere a ZFS di montare correttamente i pool su /storage."
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

# Messaggio finale
info "Installazione completata!"
info "Puoi accedere all'interfaccia web di ArmNAS all'indirizzo: http://$IP_ADDRESS"
info "Credenziali di accesso predefinite:"
info "  Username: admin"
info "  Password: admin"
warn "Si consiglia di cambiare la password predefinita dopo il primo accesso."
info "Se riscontri problemi, esegui gli script di correzione:"
info "  sudo $INSTALL_DIR/fix_permissions.sh  # Per correggere i permessi"
info "  sudo $INSTALL_DIR/fix_nginx.sh        # Per correggere la configurazione di Nginx"
info "  sudo $INSTALL_DIR/fix_backend.sh      # Per correggere e riavviare il backend"

exit 0