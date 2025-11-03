#!/usr/bin/env python3
"""
Script per creare pacchetti di aggiornamento autoinstallanti per ArmNAS
Genera file .run che contengono tutto il necessario per l'aggiornamento
"""

import os
import sys
import json
import shutil
import tarfile
import hashlib
import argparse
import tempfile
from datetime import datetime
from pathlib import Path

class UpdatePackageBuilder:
    def __init__(self, version, output_dir="./updates"):
        self.version = version
        self.output_dir = Path(output_dir)
        self.output_dir.mkdir(exist_ok=True)
        self.temp_dir = None
        
    def create_package(self, source_dir=".", changelog=None, critical=False):
        """Crea il pacchetto di aggiornamento"""
        print(f"🚀 Creazione pacchetto aggiornamento v{self.version}")
        
        # Verifica prerequisiti
        if not self._check_prerequisites(source_dir):
            return None
        
        # Crea directory temporanea
        self.temp_dir = tempfile.mkdtemp(prefix="armnas_update_")
        print(f"📁 Directory temporanea: {self.temp_dir}")
        
        try:
            # 1. Prepara i file
            package_dir = Path(self.temp_dir) / "package"
            package_dir.mkdir()
            
            self._copy_source_files(source_dir, package_dir)
            self._create_metadata(package_dir, changelog, critical)
            self._create_install_script(package_dir)
            
            # 2. Crea l'archivio
            archive_path = self._create_archive(package_dir)
            
            # 3. Crea il file .run autoinstallante
            run_file = self._create_run_file(archive_path)
            
            print(f"✅ Pacchetto creato: {run_file}")
            return run_file
            
        finally:
            # Pulisci directory temporanea
            if self.temp_dir and os.path.exists(self.temp_dir):
                shutil.rmtree(self.temp_dir)
    
    def _check_prerequisites(self, source_dir):
        """Verifica che tutti i prerequisiti siano soddisfatti"""
        print("🔍 Verifica prerequisiti...")
        source_path = Path(source_dir)
        
        # Verifica che la directory sorgente esista
        if not source_path.exists():
            print(f"❌ Directory sorgente non trovata: {source_dir}")
            return False
        
        # Verifica che esista almeno il backend
        backend_dir = source_path / "backend"
        if not backend_dir.exists():
            print("❌ Directory backend non trovata")
            return False
        
        # Verifica file essenziali del backend
        essential_files = ["main.py", "requirements.txt"]
        for file in essential_files:
            if not (backend_dir / file).exists():
                print(f"❌ File essenziale mancante: backend/{file}")
                return False
        
        # Verifica frontend (opzionale ma consigliato)
        frontend_dist = source_path / "frontend" / "dist"
        frontend_src = source_path / "frontend"
        
        if not frontend_dist.exists():
            if frontend_src.exists():
                print("⚠️  Frontend non compilato - verrà tentata la compilazione automatica")
            else:
                print("⚠️  Directory frontend non trovata - il pacchetto non includerà il frontend")
        
        print("✅ Prerequisiti verificati")
        return True
    
    def _copy_source_files(self, source_dir, package_dir):
        """Copia i file sorgente nel pacchetto"""
        print("📦 Copia file sorgente...")
        source_path = Path(source_dir)
        print(f"  📁 Directory sorgente: {source_path.absolute()}")
        print(f"  📁 Directory pacchetto: {package_dir.absolute()}")
        
        # Backend
        backend_src = source_path / "backend"
        if backend_src.exists():
            print(f"  🐍 Backend: {backend_src} -> {package_dir / 'backend'}")
            backend_dst = package_dir / "backend"
            
            # Conta i file prima della copia
            backend_files = list(backend_src.rglob('*'))
            print(f"    📊 File backend da copiare: {len(backend_files)}")
            
            shutil.copytree(backend_src, backend_dst, ignore=shutil.ignore_patterns(
                '__pycache__', '*.pyc', '*.pyo', '.git*', 'venv', '.env*', 'armnas.db'
            ))
            
            # Verifica copia
            copied_files = list(backend_dst.rglob('*'))
            print(f"    ✅ File backend copiati: {len(copied_files)}")
        else:
            print(f"  ❌ Directory backend non trovata: {backend_src}")
        
        # Frontend - Copia tutto il codice sorgente per ricompilazione sul server
        frontend_src = source_path / "frontend"
        if frontend_src.exists():
            print(f"  🌐 Frontend: {frontend_src} -> {package_dir / 'frontend'}")
            frontend_dst = package_dir / "frontend"
            
            # Conta i file prima della copia (escludendo node_modules)
            frontend_files = [f for f in frontend_src.rglob('*') if 'node_modules' not in f.parts]
            print(f"    📊 File frontend da copiare: {len(frontend_files)}")
            
            # Copia tutto il frontend escludendo node_modules e dist
            shutil.copytree(frontend_src, frontend_dst, ignore=shutil.ignore_patterns(
                'node_modules', '.git*', '*.log', '.DS_Store', 'Thumbs.db'
            ))
            
            # Verifica copia
            copied_files = list(frontend_dst.rglob('*'))
            print(f"    ✅ File frontend copiati: {len(copied_files)}")
            
            # Se esiste una build già compilata, copiala come fallback
            frontend_dist = source_path / "frontend" / "dist"
            if frontend_dist.exists():
                print("  📦 Incluso anche frontend precompilato come fallback...")
                dist_files = list(frontend_dist.rglob('*'))
                print(f"    📊 File dist da copiare: {len(dist_files)}")
                
                dist_dst = frontend_dst / "dist"
                if dist_dst.exists():
                    shutil.rmtree(dist_dst)
                shutil.copytree(frontend_dist, dist_dst)
        else:
            print(f"  ❌ Directory frontend non trovata: {frontend_src}")
        
        # Script di sistema - COPIA TUTTI gli script .sh dalla root
        print("  📜 Copia script di sistema...")
        script_count = 0
        for script_file in source_path.glob("*.sh"):
            print(f"    📜 {script_file.name}")
            shutil.copy2(script_file, package_dir)
            # Rendi eseguibile
            os.chmod(package_dir / script_file.name, 0o755)
            script_count += 1
        print(f"    ✅ Script copiati: {script_count}")
        
        # File di configurazione
        for conf_file in source_path.glob("*.conf"):
            print(f"  ⚙️  {conf_file.name}")
            shutil.copy2(conf_file, package_dir)
        
        # Docker compose file
        for compose_file in source_path.glob("docker-compose*.yml"):
            print(f"  🐳 {compose_file.name}")
            shutil.copy2(compose_file, package_dir)
    
    def _create_metadata(self, package_dir, changelog, critical):
        """Crea il file metadata.json"""
        print("📋 Creazione metadata...")
        
        metadata = {
            "version": self.version,
            "timestamp": datetime.now().isoformat(),
            "critical": critical,
            "changelog": changelog or f"Aggiornamento alla versione {self.version}",
            "files": self._get_file_list(package_dir)
        }
        
        metadata_file = package_dir / "metadata.json"
        with open(metadata_file, 'w', encoding='utf-8') as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)
    
    def _get_file_list(self, package_dir):
        """Ottiene la lista dei file nel pacchetto"""
        files = []
        for root, dirs, filenames in os.walk(package_dir):
            for filename in filenames:
                if filename == "metadata.json":
                    continue
                file_path = Path(root) / filename
                rel_path = file_path.relative_to(package_dir)
                files.append(str(rel_path))
        return files
    
    def _create_install_script(self, package_dir):
        """Crea lo script di aggiornamento semplificato"""
        print("📜 Creazione script di aggiornamento...")
        
        install_script = '''#!/bin/bash
set -e

# Script di aggiornamento ArmNAS
INSTALL_DIR="/opt/armnas"
BACKUP_DIR="/opt/armnas/backups"
SERVICE_NAME="armnas-backend"
NGINX_SERVICE="nginx"

echo "🚀 Aggiornamento ArmNAS v$(cat metadata.json | grep version | cut -d'"' -f4)"

# Funzione per logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Funzione per gestire errori
handle_error() {
    log "❌ ERRORE: $1"
    exit 1
}

# Verifica privilegi root
if [[ $EUID -ne 0 ]]; then
    handle_error "Questo script deve essere eseguito come root"
fi

# Verifica che ArmNAS sia già installato
if [[ ! -d "$INSTALL_DIR" ]]; then
    handle_error "ArmNAS non sembra essere installato in $INSTALL_DIR"
fi

# Parsing argomenti
AUTO_INSTALL="false"
BACKUP_PATH=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --auto)
            AUTO_INSTALL="true"
            shift
            ;;
        --backup)
            BACKUP_PATH="$2"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

# Conferma aggiornamento (se non auto)
if [[ "$AUTO_INSTALL" != "true" ]]; then
    read -p "Procedere con l'aggiornamento? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log "Aggiornamento annullato"
        exit 0
    fi
fi

log "📋 Caricamento metadata..."
if [[ ! -f "metadata.json" ]]; then
    handle_error "File metadata.json non trovato"
fi

VERSION=$(cat metadata.json | grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' | cut -d'"' -f4 | tr -d '\n\r')
log "Versione da installare: $VERSION"

# Crea backup automatico
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
AUTO_BACKUP_PATH="$BACKUP_DIR/backup_pre_update_${VERSION}_${TIMESTAMP}.tar.gz"

log "💾 Creazione backup automatico..."
mkdir -p "$BACKUP_DIR"

# Ferma temporaneamente i servizi per evitare modifiche ai file durante il backup
log "⏸️  Arresto temporaneo servizi per backup sicuro..."
BACKEND_WAS_RUNNING=false
NGINX_WAS_RUNNING=false

if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    BACKEND_WAS_RUNNING=true
    systemctl stop "$SERVICE_NAME" || log "⚠️  Impossibile fermare temporaneamente $SERVICE_NAME"
fi

if systemctl is-active --quiet "$NGINX_SERVICE" 2>/dev/null; then
    NGINX_WAS_RUNNING=true
    systemctl stop "$NGINX_SERVICE" || log "⚠️  Impossibile fermare temporaneamente $NGINX_SERVICE"
fi

# Attendi che i processi si fermino completamente
sleep 2

# Crea il backup escludendo file che potrebbero cambiare
tar -czf "$AUTO_BACKUP_PATH" \
    -C "$(dirname "$INSTALL_DIR")" \
    --exclude="$(basename "$INSTALL_DIR")/backend/__pycache__" \
    --exclude="$(basename "$INSTALL_DIR")/backend/*.pyc" \
    --exclude="$(basename "$INSTALL_DIR")/backend/*.pyo" \
    --exclude="$(basename "$INSTALL_DIR")/backend/venv" \
    --exclude="$(basename "$INSTALL_DIR")/backend/*.log" \
    --exclude="$(basename "$INSTALL_DIR")/backend/logs" \
    --exclude="$(basename "$INSTALL_DIR")/backups" \
    --exclude="$(basename "$INSTALL_DIR")/tmp" \
    --exclude="$(basename "$INSTALL_DIR")/.git*" \
    "$(basename "$INSTALL_DIR")" || handle_error "Errore nella creazione del backup"

# Riavvia i servizi se erano attivi
if [ "$BACKEND_WAS_RUNNING" = true ]; then
    systemctl start "$SERVICE_NAME" || log "⚠️  Impossibile riavviare $SERVICE_NAME"
fi

if [ "$NGINX_WAS_RUNNING" = true ]; then
    systemctl start "$NGINX_SERVICE" || log "⚠️  Impossibile riavviare $NGINX_SERVICE"
fi

log "✅ Backup creato: $AUTO_BACKUP_PATH"

# Crea backup aggiuntivo se richiesto
if [[ -n "$BACKUP_PATH" ]]; then
    log "💾 Creazione backup aggiuntivo in $BACKUP_PATH..."
    mkdir -p "$(dirname "$BACKUP_PATH")"
    cp "$AUTO_BACKUP_PATH" "$BACKUP_PATH" || handle_error "Errore nella copia del backup"
fi

# Ferma i servizi per l'aggiornamento
log "⏹️  Arresto servizi per aggiornamento..."
if systemctl is-active --quiet "$SERVICE_NAME" 2>/dev/null; then
    systemctl stop "$SERVICE_NAME" || log "⚠️  Impossibile fermare $SERVICE_NAME"
fi

if systemctl is-active --quiet "$NGINX_SERVICE" 2>/dev/null; then
    systemctl stop "$NGINX_SERVICE" || log "⚠️  Impossibile fermare $NGINX_SERVICE"
fi

# Backup configurazioni critiche
log "💾 Backup configurazioni..."
TEMP_CONFIG_DIR="/tmp/armnas_config_backup_$$"
mkdir -p "$TEMP_CONFIG_DIR"

# Backup configurazione backend se esiste
if [[ -f "$INSTALL_DIR/backend/config.py" ]]; then
    cp "$INSTALL_DIR/backend/config.py" "$TEMP_CONFIG_DIR/"
fi

# Backup database se esiste
if [[ -f "$INSTALL_DIR/backend/armnas.db" ]]; then
    cp "$INSTALL_DIR/backend/armnas.db" "$TEMP_CONFIG_DIR/"
fi

# Aggiorna Backend
if [[ -d "backend" ]]; then
    log "🐍 Aggiornamento backend..."
    # Mantieni l'ambiente virtuale se esiste
    if [[ -d "$INSTALL_DIR/backend/venv" ]]; then
        log "  📦 Mantenimento ambiente virtuale..."
        mv "$INSTALL_DIR/backend/venv" "$TEMP_CONFIG_DIR/"
    fi
    
    # Copia nuovi file backend
    cp -r backend/* "$INSTALL_DIR/backend/" || handle_error "Errore nell'aggiornamento del backend"
    
    # Ripristina ambiente virtuale
    if [[ -d "$TEMP_CONFIG_DIR/venv" ]]; then
        mv "$TEMP_CONFIG_DIR/venv" "$INSTALL_DIR/backend/"
    fi
    
    # Aggiorna dipendenze se necessario
    if [[ -f "$INSTALL_DIR/backend/requirements.txt" && -d "$INSTALL_DIR/backend/venv" ]]; then
        log "  📚 Aggiornamento dipendenze Python..."
        source "$INSTALL_DIR/backend/venv/bin/activate"
        pip install --upgrade pip
        pip install -r "$INSTALL_DIR/backend/requirements.txt" || log "⚠️  Errore nell'aggiornamento delle dipendenze"
        deactivate
    fi
fi

# Aggiorna Frontend
if [[ -d "frontend" ]]; then
    log "🌐 Aggiornamento frontend..."
    
    # Backup del frontend esistente
    if [[ -d "$INSTALL_DIR/frontend" ]]; then
        log "  💾 Backup frontend esistente..."
        mv "$INSTALL_DIR/frontend" "$TEMP_CONFIG_DIR/frontend_backup"
    fi
    
    # Copia il nuovo codice sorgente
    log "  📁 Copia codice sorgente frontend..."
    cp -r frontend "$INSTALL_DIR/" || handle_error "Errore nella copia del frontend"
    
    # Prova a ricompilare il frontend sul server
    log "  🔨 Ricompilazione frontend sul server..."
    cd "$INSTALL_DIR/frontend"
    
    # Verifica se npm è disponibile
    if command -v npm >/dev/null 2>&1; then
        log "  📦 Installazione dipendenze npm..."
        npm install --production=false 2>/dev/null || {
            log "  ⚠️  Errore nell'installazione dipendenze npm"
            # Prova con yarn se disponibile
            if command -v yarn >/dev/null 2>&1; then
                log "  🧶 Tentativo con yarn..."
                yarn install 2>/dev/null || log "  ⚠️  Errore anche con yarn"
            fi
        }
        
        log "  🏗️  Build di produzione..."
        npm run build 2>/dev/null || {
            log "  ⚠️  Errore nella build npm"
            # Se la build fallisce, usa il dist precompilato se disponibile
            if [[ -d "dist" ]]; then
                log "  📦 Uso frontend precompilato come fallback"
            else
                log "  ❌ Nessun frontend disponibile!"
                # Ripristina il backup se disponibile
                if [[ -d "$TEMP_CONFIG_DIR/frontend_backup" ]]; then
                    log "  🔄 Ripristino frontend precedente..."
                    rm -rf "$INSTALL_DIR/frontend"
                    mv "$TEMP_CONFIG_DIR/frontend_backup" "$INSTALL_DIR/frontend"
                fi
            fi
        }
        
        # Verifica che la build sia riuscita
        if [[ -d "$INSTALL_DIR/frontend/dist" ]]; then
            log "  ✅ Frontend ricompilato con successo"
            # Pulisci node_modules per risparmiare spazio (opzionale)
            # rm -rf "$INSTALL_DIR/frontend/node_modules"
        else
            log "  ⚠️  Build frontend non riuscita, mantengo il codice sorgente"
        fi
    else
        log "  ⚠️  npm non disponibile, impossibile ricompilare"
        log "  💡 Il frontend dovrà essere compilato manualmente"
        
        # Se c'è un dist precompilato, usalo
        if [[ -d "$INSTALL_DIR/frontend/dist" ]]; then
            log "  📦 Uso frontend precompilato incluso nel pacchetto"
        else
            log "  ❌ Nessun frontend compilato disponibile!"
        fi
    fi
    
    # Torna alla directory di installazione
    cd - >/dev/null
else
    log "  ⚠️  Nessun aggiornamento frontend nel pacchetto"
fi

# Aggiorna Script di sistema
log "📜 Aggiornamento script..."
for script in *.sh; do
    if [[ -f "$script" ]]; then
        cp "$script" "$INSTALL_DIR/" || handle_error "Errore nell'aggiornamento degli script"
        chmod +x "$INSTALL_DIR/$script"
    fi
done

# Aggiorna Configurazioni
log "⚙️  Aggiornamento configurazioni..."
for conf in *.conf; do
    if [[ -f "$conf" ]]; then
        # Backup configurazione esistente
        if [[ -f "$INSTALL_DIR/$conf" ]]; then
            cp "$INSTALL_DIR/$conf" "$TEMP_CONFIG_DIR/$conf.old"
        fi
        cp "$conf" "$INSTALL_DIR/" || handle_error "Errore nell'aggiornamento delle configurazioni"
    fi
done

# Aggiorna Docker Compose files
log "🐳 Aggiornamento docker compose..."
for compose in docker-compose*.yml; do
    if [[ -f "$compose" ]]; then
        cp "$compose" "$INSTALL_DIR/" || handle_error "Errore nell'aggiornamento dei file docker compose"
        log "  ✅ Copiato $compose"
    fi
done

# Ripristina configurazioni critiche
log "🔄 Ripristino configurazioni..."
if [[ -f "$TEMP_CONFIG_DIR/config.py" ]]; then
    cp "$TEMP_CONFIG_DIR/config.py" "$INSTALL_DIR/backend/"
fi

if [[ -f "$TEMP_CONFIG_DIR/armnas.db" ]]; then
    cp "$TEMP_CONFIG_DIR/armnas.db" "$INSTALL_DIR/backend/"
    log "✅ Database utenti ripristinato"
else
    log "⚠️  Database utenti non trovato - potrebbe essere necessario ricreare gli utenti admin"
fi

# Aggiorna permessi
log "🔐 Aggiornamento permessi..."
chown -R www-data:www-data "$INSTALL_DIR" 2>/dev/null || log "⚠️  Impossibile impostare proprietario www-data"
chmod +x "$INSTALL_DIR"/*.sh 2>/dev/null || true

# Riavvia servizi
log "🔄 Riavvio servizi..."

# Verifica configurazione nginx prima del riavvio
if command -v nginx >/dev/null 2>&1; then
    log "  🔍 Verifica configurazione nginx..."
    nginx -t 2>/dev/null || log "  ⚠️  Configurazione nginx potrebbe avere problemi"
fi

if systemctl list-unit-files | grep -q "$NGINX_SERVICE"; then
    systemctl start "$NGINX_SERVICE" || log "⚠️  Impossibile riavviare $NGINX_SERVICE"
    
    # Verifica che nginx sia attivo
    sleep 2
    if systemctl is-active --quiet "$NGINX_SERVICE"; then
        log "✅ Nginx riavviato correttamente"
    else
        log "⚠️  Nginx non è attivo dopo il riavvio"
    fi
fi

if systemctl list-unit-files | grep -q "$SERVICE_NAME"; then
    systemctl start "$SERVICE_NAME" || log "⚠️  Impossibile riavviare $SERVICE_NAME"
    
    # Verifica stato servizio
    sleep 3
    if systemctl is-active --quiet "$SERVICE_NAME"; then
        log "✅ Servizio $SERVICE_NAME riavviato correttamente"
    else
        log "⚠️  Il servizio $SERVICE_NAME non è attivo"
        log "🔧 Controllare i log: journalctl -u $SERVICE_NAME -f"
    fi
else
    log "⚠️  Servizio $SERVICE_NAME non trovato nel sistema"
fi

# Verifica utenti admin
log "👑 Verifica utenti amministratori..."
if [[ -f "$INSTALL_DIR/backend/armnas.db" ]]; then
    # Controlla se ci sono utenti admin nel database
    ADMIN_COUNT=$(sqlite3 "$INSTALL_DIR/backend/armnas.db" "SELECT COUNT(*) FROM users WHERE is_admin = 1;" 2>/dev/null || echo "0")
    if [[ "$ADMIN_COUNT" -gt 0 ]]; then
        log "✅ Trovati $ADMIN_COUNT utenti amministratori"
    else
        log "⚠️  ATTENZIONE: Nessun utente amministratore trovato!"
        log "   La voce 'Aggiornamenti' potrebbe non apparire nella sidebar."
        log "   Esegui: python3 $INSTALL_DIR/backend/fix_admin_user.py"
    fi
else
    log "⚠️  Database utenti non trovato"
fi

# Pulizia
log "🧹 Pulizia file temporanei..."
rm -rf "$TEMP_CONFIG_DIR"

log "🎉 Aggiornamento completato!"
log "📍 Directory installazione: $INSTALL_DIR"
log "💾 Backup salvato in: $AUTO_BACKUP_PATH"
log "🔧 Per verificare lo stato: systemctl status $SERVICE_NAME"
log "🌐 Per verificare nginx: systemctl status $NGINX_SERVICE"

exit 0
'''
        
        script_file = package_dir / "install.sh"
        with open(script_file, 'w', encoding='utf-8') as f:
            f.write(install_script)
        
        # Rendi eseguibile
        os.chmod(script_file, 0o755)
    
    def _create_archive(self, package_dir):
        """Crea l'archivio tar.gz"""
        print("🗜️  Creazione archivio...")
        
        # Conta i file nel pacchetto
        all_files = list(package_dir.rglob('*'))
        print(f"  📊 File totali nel pacchetto: {len(all_files)}")
        
        # Calcola dimensione totale
        total_size = sum(f.stat().st_size for f in all_files if f.is_file())
        print(f"  📏 Dimensione totale: {total_size / (1024*1024):.1f} MB")
        
        archive_path = Path(self.temp_dir) / "package.tar.gz"
        
        with tarfile.open(archive_path, "w:gz") as tar:
            tar.add(package_dir, arcname=".")
        
        # Verifica dimensione archivio
        archive_size = archive_path.stat().st_size
        print(f"  📦 Dimensione archivio: {archive_size / (1024*1024):.1f} MB")
        
        return archive_path
    
    def _create_run_file(self, archive_path):
        """Crea il file .run autoinstallante usando makeself se disponibile"""
        print("🔧 Creazione file .run...")
        
        run_filename = f"armnas_update_v{self.version}.run"
        run_path = self.output_dir / run_filename
        
        # Prova prima con makeself
        if self._try_makeself(archive_path, run_path):
            print("✅ File .run creato con makeself")
        else:
            print("⚠️  makeself non disponibile, uso metodo manuale")
            self._create_run_file_manual(archive_path, run_path)
        
        # Crea file info
        self._create_info_file(run_path)
        
        return run_path
    
    def _try_makeself(self, archive_path, run_path):
        """Prova a usare makeself per creare il file .run"""
        try:
            import subprocess
            
            # Verifica se makeself è disponibile
            result = subprocess.run(['which', 'makeself'], capture_output=True, text=True)
            if result.returncode != 0:
                return False
            
            # Estrai l'archivio in una directory temporanea per makeself
            temp_extract_dir = tempfile.mkdtemp(prefix="makeself_")
            
            try:
                with tarfile.open(archive_path, "r:gz") as tar:
                    tar.extractall(temp_extract_dir)
                
                # Usa makeself per creare il file .run
                makeself_cmd = [
                    'makeself',
                    '--gzip',
                    '--notemp',
                    temp_extract_dir,
                    str(run_path),
                    f"ArmNAS Update v{self.version}",
                    './launch.sh'
                ]
                
                result = subprocess.run(makeself_cmd, capture_output=True, text=True)
                
                if result.returncode == 0:
                    print(f"✅ makeself completato: {result.stdout}")
                    return True
                else:
                    print(f"❌ Errore makeself: {result.stderr}")
                    return False
                    
            finally:
                shutil.rmtree(temp_extract_dir, ignore_errors=True)
                
        except Exception as e:
            print(f"❌ Errore nell'uso di makeself: {e}")
            return False
    
    def _create_run_file_manual(self, archive_path, run_path):
        """Crea il file .run manualmente (fallback)"""
        # Header dello script migliorato
        header = '''#!/bin/bash
# ArmNAS Auto-installer v{version}
# Generato il {timestamp}

set -e

# Funzione per logging
log() {{
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}}

# Funzione per gestire errori
handle_error() {{
    log "❌ ERRORE: $1"
    exit 1
}}

log "🚀 Avvio installazione ArmNAS v{version}"

# Trova la posizione dell'archivio
ARCHIVE_START_LINE=$(awk '/^__ARCHIVE_BELOW__/ {{print NR + 1; exit 0; }}' "$0")

if [[ -z "$ARCHIVE_START_LINE" ]]; then
    handle_error "Marker archivio non trovato"
fi

log "📦 Estrazione archivio..."

# Crea directory temporanea
TEMP_DIR=$(mktemp -d)
if [[ ! -d "$TEMP_DIR" ]]; then
    handle_error "Impossibile creare directory temporanea"
fi

# Funzione di pulizia
cleanup() {{
    log "🧹 Pulizia file temporanei..."
    cd /
    rm -rf "$TEMP_DIR"
}}

# Imposta trap per pulizia automatica
trap cleanup EXIT

# Estrai archivio
tail -n +$ARCHIVE_START_LINE "$0" | tar -xzf - -C "$TEMP_DIR" || handle_error "Errore nell'estrazione dell'archivio"

# Verifica che launch.sh esista
if [[ ! -f "$TEMP_DIR/launch.sh" ]]; then
    handle_error "Script launch.sh non trovato nell'archivio"
fi

# Esegui installazione
log "🔧 Esecuzione installazione..."
cd "$TEMP_DIR"
chmod +x launch.sh
./launch.sh "$@"

log "✅ Installazione completata"
exit 0

__ARCHIVE_BELOW__
'''.format(version=self.version, timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"))
        
        # Scrivi il file .run
        with open(run_path, 'wb') as run_file:
            # Header
            run_file.write(header.encode('utf-8'))
            
            # Archivio
            with open(archive_path, 'rb') as archive_file:
                shutil.copyfileobj(archive_file, run_file)
        
        # Rendi eseguibile
        os.chmod(run_path, 0o755)
    
    def _create_info_file(self, run_path):
        """Crea file .info con informazioni sul pacchetto"""
        info_path = Path(str(run_path) + ".info")
        
        # Calcola hash
        sha256_hash = hashlib.sha256()
        with open(run_path, "rb") as f:
            for chunk in iter(lambda: f.read(4096), b""):
                sha256_hash.update(chunk)
        
        info = {
            "version": self.version,
            "filename": run_path.name,
            "size": os.path.getsize(run_path),
            "sha256": sha256_hash.hexdigest(),
            "created": datetime.now().isoformat()
        }
        
        with open(info_path, 'w', encoding='utf-8') as f:
            json.dump(info, f, indent=2, ensure_ascii=False)

def main():
    print("🚀 Avvio creazione pacchetto ArmNAS...")
    parser = argparse.ArgumentParser(description="Crea pacchetti di aggiornamento ArmNAS")
    parser.add_argument("version", help="Versione del pacchetto (es: 0.1.2)")
    parser.add_argument("--source", "-s", default=".", help="Directory sorgente (default: .)")
    parser.add_argument("--output", "-o", default="./updates", help="Directory output (default: ./updates)")
    parser.add_argument("--changelog", "-c", help="Messaggio di changelog")
    parser.add_argument("--critical", action="store_true", help="Aggiornamento critico")
    
    args = parser.parse_args()
    
    # Verifica che la directory sorgente esista
    if not os.path.exists(args.source):
        print(f"❌ Directory sorgente non trovata: {args.source}")
        sys.exit(1)
    
    # Crea il builder
    builder = UpdatePackageBuilder(args.version, args.output)
    
    try:
        # Crea il pacchetto
        package_file = builder.create_package(
            source_dir=args.source,
            changelog=args.changelog,
            critical=args.critical
        )
        
        print(f"\n🎉 Pacchetto creato con successo!")
        print(f"📁 File: {package_file}")
        print(f"📋 Info: {package_file}.info")
        print(f"\n💡 Per installare: sudo bash {package_file}")
        
    except Exception as e:
        print(f"❌ Errore durante la creazione del pacchetto: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()