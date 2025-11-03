#!/bin/bash
# Script di lancio per pacchetti di aggiornamento ArmNAS
# Questo script viene eseguito automaticamente dal pacchetto .run

set -e

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per logging colorato
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Banner
echo "=================================="
echo "   ArmNAS Update Installer"
echo "=================================="
echo ""

# Verifica privilegi root
if [[ $EUID -ne 0 ]]; then
    log_error "Questo script deve essere eseguito come root"
    log_info "Riavviare con: sudo $0 $@"
    exit 1
fi

# Verifica che install.sh esista
if [[ ! -f "./install.sh" ]]; then
    log_error "File install.sh non trovato nella directory corrente"
    exit 1
fi

# Rendi eseguibile install.sh
chmod +x ./install.sh

# Carica metadata se esiste
if [[ -f "./metadata.json" ]]; then
    if command -v jq >/dev/null 2>&1; then
        VERSION=$(jq -r '.version' metadata.json 2>/dev/null || echo "unknown")
        TIMESTAMP=$(jq -r '.timestamp' metadata.json 2>/dev/null || echo "unknown")
        CRITICAL=$(jq -r '.critical' metadata.json 2>/dev/null || echo "false")
    else
        VERSION=$(grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' metadata.json | cut -d'"' -f4 | tr -d '\n\r' || echo "unknown")
        TIMESTAMP=$(grep -o '"timestamp"[[:space:]]*:[[:space:]]*"[^"]*"' metadata.json | cut -d'"' -f4 | tr -d '\n\r' || echo "unknown")
        CRITICAL=$(grep -o '"critical"[[:space:]]*:[[:space:]]*[^,}]*' metadata.json | awk -F': ' '{print $2}' | tr -d ' \n\r' || echo "false")
    fi
    
    log_info "Versione: ${VERSION}"
    log_info "Build: ${TIMESTAMP}"
    
    if [[ "$CRITICAL" == "true" ]]; then
        log_warning "⚠️  AGGIORNAMENTO CRITICO - Installazione fortemente consigliata"
    fi
else
    log_warning "File metadata.json non trovato - procedura standard"
fi

echo ""
log_info "🚀 Avvio installazione..."
echo ""

# Esegui install.sh passando tutti gli argomenti
if ./install.sh "$@"; then
    log_success "✅ Installazione completata con successo!"
    
    # Esegui script post-installazione se esistono
    INSTALL_DIR="/opt/armnas"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        log_info "Esecuzione script di post-installazione..."
        
        # Fix permissions
        if [[ -f "$INSTALL_DIR/fix_permissions.sh" ]]; then
            log_info "  - Correzione permessi..."
            bash "$INSTALL_DIR/fix_permissions.sh" 2>&1 | sed 's/^/    /'
        fi
        
        # Fix nginx
        if [[ -f "$INSTALL_DIR/fix_nginx.sh" ]]; then
            log_info "  - Configurazione nginx..."
            bash "$INSTALL_DIR/fix_nginx.sh" 2>&1 | sed 's/^/    /'
        fi
        
        # Fix backend
        if [[ -f "$INSTALL_DIR/fix_backend.sh" ]]; then
            log_info "  - Configurazione backend..."
            bash "$INSTALL_DIR/fix_backend.sh" 2>&1 | sed 's/^/    /'
        fi
        
        log_success "Script post-installazione completati"
    fi
    
    echo ""
    echo "=================================="
    log_success "🎉 Aggiornamento completato!"
    echo "=================================="
    echo ""
    log_info "Il sistema è stato aggiornato con successo."
    log_info "Verifica lo stato dei servizi:"
    echo ""
    echo "  systemctl status armnas-backend"
    echo "  systemctl status nginx"
    echo ""
    
    # Suggerisci di controllare i log se ci sono problemi
    log_info "In caso di problemi, controlla i log:"
    echo "  journalctl -u armnas-backend -f"
    echo "  journalctl -u nginx -f"
    echo ""
    
    exit 0
else
    log_error "❌ Installazione fallita!"
    echo ""
    log_warning "L'installazione ha riscontrato degli errori."
    log_info "Controlla i messaggi precedenti per dettagli."
    echo ""
    log_info "Puoi provare a ripristinare un backup precedente."
    log_info "I backup sono salvati in: /opt/armnas/backups"
    echo ""
    
    exit 1
fi

