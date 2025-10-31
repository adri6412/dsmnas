#!/bin/bash

# Script di utilità per gestire gli aggiornamenti ArmNAS
# Fornisce comandi per creare, testare e distribuire aggiornamenti

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPDATE_DIR="$SCRIPT_DIR/updates"
PYTHON_SCRIPT="$SCRIPT_DIR/create_update_package.py"
SERVER_SCRIPT="$SCRIPT_DIR/update_server_example.py"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzioni di utilità
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Funzione per mostrare l'help
show_help() {
    cat << EOF
🚀 ArmNAS Update Manager

Utilizzo: $0 <comando> [opzioni]

Comandi disponibili:
  create <version>              Crea un nuovo pacchetto di aggiornamento
  list                         Lista i pacchetti disponibili
  test <package>               Testa un pacchetto di aggiornamento
  server                       Avvia il server di aggiornamenti
  install <package>            Installa un pacchetto localmente
  clean                        Pulisce i file temporanei
  help                         Mostra questo messaggio

Opzioni per 'create':
  --changelog "msg1,msg2"      Lista delle modifiche (separata da virgole)
  --critical                   Marca come aggiornamento critico
  --source <dir>               Directory sorgente (default: .)

Esempi:
  $0 create 1.2.3 --changelog "Nuove funzionalità,Correzioni bug" --critical
  $0 test updates/armnas_update_v1.2.3.run
  $0 server
  $0 install updates/armnas_update_v1.2.3.run

EOF
}

# Funzione per creare un pacchetto
create_package() {
    local version="$1"
    shift
    
    if [[ -z "$version" ]]; then
        log_error "Versione richiesta"
        echo "Utilizzo: $0 create <version> [opzioni]"
        exit 1
    fi
    
    log_info "Creazione pacchetto v$version..."
    
    # Verifica che lo script Python esista
    if [[ ! -f "$PYTHON_SCRIPT" ]]; then
        log_error "Script Python non trovato: $PYTHON_SCRIPT"
        exit 1
    fi
    
    # Crea directory updates se non esiste
    mkdir -p "$UPDATE_DIR"
    
    # Esegui lo script Python
    python3 "$PYTHON_SCRIPT" "$version" --output "$UPDATE_DIR" "$@"
    
    if [[ $? -eq 0 ]]; then
        log_success "Pacchetto v$version creato con successo!"
        
        # Mostra informazioni sul pacchetto
        local package_file="$UPDATE_DIR/armnas_update_v$version.run"
        if [[ -f "$package_file" ]]; then
            local size=$(du -h "$package_file" | cut -f1)
            log_info "File: $package_file"
            log_info "Dimensione: $size"
            
            # Mostra checksum se disponibile
            local info_file="$UPDATE_DIR/armnas_update_v$version.run.info"
            if [[ -f "$info_file" ]]; then
                local checksum=$(grep -o '"checksum": "[^"]*"' "$info_file" | cut -d'"' -f4)
                log_info "Checksum: $checksum"
            fi
        fi
    else
        log_error "Errore nella creazione del pacchetto"
        exit 1
    fi
}

# Funzione per listare i pacchetti
list_packages() {
    log_info "Pacchetti di aggiornamento disponibili:"
    
    if [[ ! -d "$UPDATE_DIR" ]]; then
        log_warning "Directory updates non trovata"
        return
    fi
    
    local found=false
    for package in "$UPDATE_DIR"/*.run; do
        if [[ -f "$package" ]]; then
            found=true
            local filename=$(basename "$package")
            local size=$(du -h "$package" | cut -f1)
            local date=$(stat -c %y "$package" | cut -d' ' -f1)
            
            echo "  📦 $filename ($size) - $date"
            
            # Mostra info aggiuntive se disponibili
            local info_file="${package}.info"
            if [[ -f "$info_file" ]]; then
                local version=$(grep -o '"version": "[^"]*"' "$info_file" | cut -d'"' -f4)
                local checksum=$(grep -o '"checksum": "[^"]*"' "$info_file" | cut -d'"' -f4 | cut -c1-8)
                echo "     Versione: $version, Checksum: ${checksum}..."
            fi
        fi
    done
    
    if [[ "$found" == false ]]; then
        log_warning "Nessun pacchetto trovato in $UPDATE_DIR"
    fi
}

# Funzione per testare un pacchetto
test_package() {
    local package="$1"
    
    if [[ -z "$package" ]]; then
        log_error "Pacchetto richiesto"
        echo "Utilizzo: $0 test <package>"
        exit 1
    fi
    
    if [[ ! -f "$package" ]]; then
        log_error "Pacchetto non trovato: $package"
        exit 1
    fi
    
    log_info "Test del pacchetto: $package"
    
    # Verifica che sia eseguibile
    if [[ ! -x "$package" ]]; then
        log_warning "Il pacchetto non è eseguibile, correzione..."
        chmod +x "$package"
    fi
    
    # Test di estrazione in directory temporanea
    local temp_dir=$(mktemp -d)
    log_info "Estrazione di test in: $temp_dir"
    
    # Simula l'estrazione
    cd "$temp_dir"
    
    # Trova la posizione dell'archivio
    local archive_start=$(awk '/^__ARCHIVE_BELOW__/ {print NR + 1; exit 0; }' "$package")
    
    if [[ -z "$archive_start" ]]; then
        log_error "Archivio non trovato nel pacchetto"
        rm -rf "$temp_dir"
        exit 1
    fi
    
    # Estrai l'archivio
    tail -n +$archive_start "$package" | tar -tzf - > /dev/null
    
    if [[ $? -eq 0 ]]; then
        log_success "Archivio valido"
        
        # Estrai per verificare il contenuto
        tail -n +$archive_start "$package" | tar -xzf -
        
        # Verifica file essenziali
        local errors=0
        
        if [[ ! -f "metadata.json" ]]; then
            log_error "File metadata.json mancante"
            errors=$((errors + 1))
        else
            log_success "metadata.json trovato"
            local version=$(grep -o '"version": "[^"]*"' metadata.json | cut -d'"' -f4)
            log_info "Versione: $version"
        fi
        
        if [[ ! -f "install.sh" ]]; then
            log_error "Script install.sh mancante"
            errors=$((errors + 1))
        else
            log_success "install.sh trovato"
        fi
        
        if [[ ! -d "backend" ]]; then
            log_warning "Directory backend mancante"
        else
            log_success "Backend trovato"
        fi
        
        if [[ ! -d "frontend/dist" ]]; then
            log_warning "Frontend dist mancante"
        else
            log_success "Frontend trovato"
        fi
        
        if [[ $errors -eq 0 ]]; then
            log_success "Test completato con successo!"
        else
            log_error "Test fallito con $errors errori"
        fi
    else
        log_error "Archivio corrotto o non valido"
    fi
    
    # Pulisci
    rm -rf "$temp_dir"
}

# Funzione per avviare il server
start_server() {
    log_info "Avvio server di aggiornamenti..."
    
    if [[ ! -f "$SERVER_SCRIPT" ]]; then
        log_error "Script server non trovato: $SERVER_SCRIPT"
        exit 1
    fi
    
    # Verifica dipendenze Python
    if ! python3 -c "import flask" 2>/dev/null; then
        log_warning "Flask non installato, installazione..."
        pip3 install flask
    fi
    
    # Crea directory updates se non esiste
    mkdir -p "$UPDATE_DIR"
    
    log_info "Server disponibile su: http://localhost:5000"
    log_info "Directory aggiornamenti: $UPDATE_DIR"
    log_info "Premi Ctrl+C per fermare il server"
    
    cd "$SCRIPT_DIR"
    python3 "$SERVER_SCRIPT"
}

# Funzione per installare un pacchetto
install_package() {
    local package="$1"
    
    if [[ -z "$package" ]]; then
        log_error "Pacchetto richiesto"
        echo "Utilizzo: $0 install <package>"
        exit 1
    fi
    
    if [[ ! -f "$package" ]]; then
        log_error "Pacchetto non trovato: $package"
        exit 1
    fi
    
    log_warning "ATTENZIONE: Questo installerà il pacchetto sul sistema corrente!"
    read -p "Continuare? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installazione annullata"
        exit 0
    fi
    
    log_info "Installazione di: $package"
    
    # Verifica permessi root
    if [[ $EUID -ne 0 ]]; then
        log_error "Installazione richiede permessi root"
        log_info "Riprova con: sudo $0 install $package"
        exit 1
    fi
    
    # Esegui il pacchetto
    chmod +x "$package"
    "$package"
}

# Funzione per pulire i file temporanei
clean_temp() {
    log_info "Pulizia file temporanei..."
    
    # Pulisci directory temporanee
    rm -rf /tmp/armnas_update_*
    rm -rf /tmp/armnas_backup_*
    
    # Pulisci file di log vecchi
    find /var/log -name "*armnas*" -mtime +30 -delete 2>/dev/null || true
    
    log_success "Pulizia completata"
}

# Main
case "${1:-}" in
    create)
        shift
        create_package "$@"
        ;;
    list)
        list_packages
        ;;
    test)
        test_package "$2"
        ;;
    server)
        start_server
        ;;
    install)
        install_package "$2"
        ;;
    clean)
        clean_temp
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        log_error "Comando richiesto"
        show_help
        exit 1
        ;;
    *)
        log_error "Comando sconosciuto: $1"
        show_help
        exit 1
        ;;
esac