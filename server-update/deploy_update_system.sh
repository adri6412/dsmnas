#!/bin/bash

# Script per deployare il sistema di aggiornamento su un sistema ArmNAS esistente
# Questo script aggiorna il sistema corrente aggiungendo le funzionalità di aggiornamento

set -e

# Configurazione
INSTALL_DIR="/opt/armnas"
BACKUP_DIR="/opt/armnas/backups"
TEMP_DIR="/tmp/armnas_deploy_$(date +%Y%m%d_%H%M%S)"
CURRENT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Verifica permessi root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Questo script deve essere eseguito come root"
        echo "Riprova con: sudo $0"
        exit 1
    fi
}

# Crea backup del sistema corrente
create_backup() {
    log_info "📦 Creazione backup del sistema corrente..."
    
    mkdir -p "$BACKUP_DIR"
    
    local backup_name="armnas_pre_update_system_$(date +%Y%m%d_%H%M%S).tar.gz"
    local backup_path="$BACKUP_DIR/$backup_name"
    
    if [[ -d "$INSTALL_DIR" ]]; then
        tar -czf "$backup_path" -C "$(dirname "$INSTALL_DIR")" "$(basename "$INSTALL_DIR")" 2>/dev/null || {
            log_warning "Errore nel backup completo, provo backup parziale..."
            tar -czf "$backup_path" -C "$INSTALL_DIR" backend frontend *.sh *.conf 2>/dev/null || {
                log_error "Impossibile creare backup"
                exit 1
            }
        }
        log_success "Backup creato: $backup_path"
        echo "$backup_path" > /tmp/armnas_backup_path
    else
        log_warning "Directory di installazione non trovata: $INSTALL_DIR"
    fi
}

# Ferma i servizi
stop_services() {
    log_info "⏹️  Arresto servizi ArmNAS..."
    
    # Prova a fermare il servizio systemd se esiste
    if systemctl is-active --quiet armnas 2>/dev/null; then
        systemctl stop armnas
        log_success "Servizio armnas fermato"
    elif systemctl is-active --quiet armnas-backend 2>/dev/null; then
        systemctl stop armnas-backend
        log_success "Servizio armnas-backend fermato"
    else
        log_warning "Nessun servizio systemd trovato"
    fi
    
    # Ferma eventuali processi Python in esecuzione
    pkill -f "python.*main.py" 2>/dev/null || true
    pkill -f "uvicorn.*main:app" 2>/dev/null || true
    
    sleep 2
}

# Avvia i servizi
start_services() {
    log_info "▶️  Avvio servizi ArmNAS..."
    
    # Prova a avviare il servizio systemd se esiste
    if systemctl list-unit-files | grep -q armnas; then
        systemctl start armnas
        systemctl enable armnas
        log_success "Servizio armnas avviato"
    elif systemctl list-unit-files | grep -q armnas-backend; then
        systemctl start armnas-backend
        systemctl enable armnas-backend
        log_success "Servizio armnas-backend avviato"
    else
        log_warning "Nessun servizio systemd configurato"
        log_info "Avvio manuale del backend..."
        cd "$INSTALL_DIR/backend"
        nohup python3 main.py > /var/log/armnas.log 2>&1 &
        log_success "Backend avviato manualmente"
    fi
}

# Deploy del backend
deploy_backend() {
    log_info "🐍 Deploy backend..."
    
    # Crea directory temporanea
    mkdir -p "$TEMP_DIR"
    
    # Copia i nuovi file del backend
    if [[ -f "$CURRENT_DIR/backend/api/routes/updates.py" ]]; then
        cp "$CURRENT_DIR/backend/api/routes/updates.py" "$INSTALL_DIR/backend/api/routes/"
        log_success "File updates.py copiato"
    else
        log_error "File updates.py non trovato in $CURRENT_DIR/backend/api/routes/"
        exit 1
    fi
    
    # Aggiorna main.py per includere il router degli aggiornamenti
    local main_py="$INSTALL_DIR/backend/main.py"
    
    if [[ -f "$main_py" ]]; then
        # Backup del main.py originale
        cp "$main_py" "$main_py.backup"
        
        # Aggiungi import se non presente
        if ! grep -q "from api.routes import.*updates" "$main_py"; then
            sed -i 's/from api.routes import \(.*\)/from api.routes import \1, updates/' "$main_py"
            log_success "Import updates aggiunto a main.py"
        fi
        
        # Aggiungi router se non presente
        if ! grep -q "app.include_router(updates.router" "$main_py"; then
            # Trova l'ultima riga con include_router e aggiungi dopo
            local last_router_line=$(grep -n "app.include_router.*router" "$main_py" | tail -1 | cut -d: -f1)
            if [[ -n "$last_router_line" ]]; then
                sed -i "${last_router_line}a\\app.include_router(updates.router, prefix=\"/api/updates\", tags=[\"Aggiornamenti\"], dependencies=[Depends(get_current_admin)])" "$main_py"
                log_success "Router updates aggiunto a main.py"
            else
                log_error "Impossibile trovare dove aggiungere il router"
                exit 1
            fi
        fi
    else
        log_error "File main.py non trovato: $main_py"
        exit 1
    fi
    
    # Aggiorna requirements.txt
    local requirements="$INSTALL_DIR/backend/requirements.txt"
    if [[ -f "$requirements" ]]; then
        if ! grep -q "requests" "$requirements"; then
            echo "requests==2.31.0" >> "$requirements"
            log_success "Dipendenza requests aggiunta"
        fi
    fi
    
    # Installa nuove dipendenze
    log_info "📚 Installazione dipendenze Python..."
    cd "$INSTALL_DIR/backend"
    pip3 install -r requirements.txt
}

# Deploy del frontend
deploy_frontend() {
    log_info "🌐 Deploy frontend..."
    
    # Copia la nuova vista
    local frontend_views="$INSTALL_DIR/frontend/src/views"
    if [[ -d "$frontend_views" ]]; then
        cp "$CURRENT_DIR/frontend/src/views/UpdateManagement.vue" "$frontend_views/"
        log_success "Vista UpdateManagement.vue copiata"
    else
        log_warning "Directory views non trovata, creazione..."
        mkdir -p "$frontend_views"
        cp "$CURRENT_DIR/frontend/src/views/UpdateManagement.vue" "$frontend_views/"
    fi
    
    # Aggiorna router
    local router_file="$INSTALL_DIR/frontend/src/router/index.js"
    if [[ -f "$router_file" ]]; then
        # Backup del router originale
        cp "$router_file" "$router_file.backup"
        
        # Aggiungi import se non presente
        if ! grep -q "UpdateManagement" "$router_file"; then
            sed -i "/import.*from.*views/a import UpdateManagement from '@/views/UpdateManagement.vue'" "$router_file"
            log_success "Import UpdateManagement aggiunto al router"
        fi
        
        # Aggiungi rotta se non presente
        if ! grep -q "path: '/updates'" "$router_file"; then
            # Trova dove aggiungere la rotta (prima del redirect finale)
            sed -i '/path.*pathMatch.*redirect/i\  {\
    path: "/updates",\
    name: "UpdateManagement",\
    component: UpdateManagement,\
    meta: { requiresAuth: true, requiresAdmin: true }\
  },' "$router_file"
            log_success "Rotta /updates aggiunta al router"
        fi
    else
        log_error "File router non trovato: $router_file"
        exit 1
    fi
    
    # Aggiorna sidebar
    local sidebar_file="$INSTALL_DIR/frontend/src/components/layout/Sidebar.vue"
    if [[ -f "$sidebar_file" ]]; then
        # Backup della sidebar originale
        cp "$sidebar_file" "$sidebar_file.backup"
        
        # Aggiungi voce menu se non presente
        if ! grep -q 'to="/updates"' "$sidebar_file"; then
            # Trova dove aggiungere la voce (dopo system)
            sed -i '/to="\/system"/,/router-link>/a\      \
      <router-link v-if="isAdmin" to="/updates" class="menu-item" :class="{ active: $route.path === \"/updates\" }">\
        <font-awesome-icon icon="download" />\
        <span v-if="!isCollapsed">{{ $t("sidebar.updates") || "Aggiornamenti" }}</span>\
      </router-link>' "$sidebar_file"
            log_success "Voce menu Aggiornamenti aggiunta alla sidebar"
        fi
    else
        log_warning "File sidebar non trovato: $sidebar_file"
    fi
    
    # Ricompila il frontend se possibile
    if command -v npm &> /dev/null && [[ -f "$INSTALL_DIR/frontend/package.json" ]]; then
        log_info "🔨 Ricompilazione frontend..."
        cd "$INSTALL_DIR/frontend"
        
        # Installa dipendenze se necessario
        if [[ ! -d "node_modules" ]]; then
            npm install
        fi
        
        # Build di produzione
        npm run build
        log_success "Frontend ricompilato"
    else
        log_warning "npm non disponibile, frontend non ricompilato"
        log_info "Dovrai ricompilare manualmente il frontend:"
        log_info "cd $INSTALL_DIR/frontend && npm install && npm run build"
    fi
}

# Deploy degli script di utilità
deploy_scripts() {
    log_info "📜 Deploy script di utilità..."
    
    # Copia gli script
    local scripts=(
        "create_update_package.py"
        "update_server_example.py"
        "manage_updates.sh"
        "build_and_release.sh"
    )
    
    for script in "${scripts[@]}"; do
        if [[ -f "$CURRENT_DIR/$script" ]]; then
            cp "$CURRENT_DIR/$script" "$INSTALL_DIR/"
            chmod +x "$INSTALL_DIR/$script"
            log_success "Script $script copiato"
        else
            log_warning "Script $script non trovato"
        fi
    done
    
    # Copia la documentazione
    if [[ -f "$CURRENT_DIR/UPDATE_SYSTEM_README.md" ]]; then
        cp "$CURRENT_DIR/UPDATE_SYSTEM_README.md" "$INSTALL_DIR/"
        log_success "Documentazione copiata"
    fi
}

# Crea directory necessarie
create_directories() {
    log_info "📁 Creazione directory necessarie..."
    
    local dirs=(
        "$INSTALL_DIR/updates"
        "$BACKUP_DIR"
        "/tmp/armnas_updates"
    )
    
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
        log_success "Directory creata: $dir"
    done
    
    # Imposta permessi
    chown -R armnas:armnas "$INSTALL_DIR" 2>/dev/null || log_warning "Impossibile impostare proprietario armnas"
}

# Verifica installazione
verify_installation() {
    log_info "🔍 Verifica installazione..."
    
    local errors=0
    
    # Verifica file backend
    if [[ -f "$INSTALL_DIR/backend/api/routes/updates.py" ]]; then
        log_success "✓ Backend: updates.py presente"
    else
        log_error "✗ Backend: updates.py mancante"
        errors=$((errors + 1))
    fi
    
    # Verifica file frontend
    if [[ -f "$INSTALL_DIR/frontend/src/views/UpdateManagement.vue" ]]; then
        log_success "✓ Frontend: UpdateManagement.vue presente"
    else
        log_error "✗ Frontend: UpdateManagement.vue mancante"
        errors=$((errors + 1))
    fi
    
    # Verifica script
    if [[ -f "$INSTALL_DIR/create_update_package.py" ]]; then
        log_success "✓ Script: create_update_package.py presente"
    else
        log_error "✗ Script: create_update_package.py mancante"
        errors=$((errors + 1))
    fi
    
    # Verifica directory
    if [[ -d "$INSTALL_DIR/updates" ]]; then
        log_success "✓ Directory: updates presente"
    else
        log_error "✗ Directory: updates mancante"
        errors=$((errors + 1))
    fi
    
    if [[ $errors -eq 0 ]]; then
        log_success "🎉 Installazione verificata con successo!"
        return 0
    else
        log_error "❌ Installazione fallita con $errors errori"
        return 1
    fi
}

# Rollback in caso di errore
rollback() {
    log_warning "🔄 Rollback in corso..."
    
    if [[ -f /tmp/armnas_backup_path ]]; then
        local backup_path=$(cat /tmp/armnas_backup_path)
        if [[ -f "$backup_path" ]]; then
            log_info "Ripristino da backup: $backup_path"
            
            # Ferma servizi
            stop_services
            
            # Ripristina backup
            tar -xzf "$backup_path" -C "$(dirname "$INSTALL_DIR")"
            
            # Riavvia servizi
            start_services
            
            log_success "Rollback completato"
        else
            log_error "File di backup non trovato: $backup_path"
        fi
    else
        log_error "Percorso backup non trovato"
    fi
}

# Funzione principale
main() {
    log_info "🚀 Deploy Sistema di Aggiornamento ArmNAS"
    log_info "Directory corrente: $CURRENT_DIR"
    log_info "Directory installazione: $INSTALL_DIR"
    
    # Verifica prerequisiti
    check_root
    
    # Verifica che i file sorgente esistano
    if [[ ! -f "$CURRENT_DIR/backend/api/routes/updates.py" ]]; then
        log_error "File updates.py non trovato. Assicurati di essere nella directory corretta."
        exit 1
    fi
    
    # Conferma dall'utente
    echo ""
    log_warning "⚠️  ATTENZIONE: Questo script modificherà il sistema ArmNAS esistente"
    log_info "Verrà creato un backup automatico prima delle modifiche"
    echo ""
    read -p "Continuare con l'installazione? (y/N): " -n 1 -r
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installazione annullata dall'utente"
        exit 0
    fi
    
    # Trap per gestire errori
    trap 'log_error "Errore durante l'\''installazione"; rollback; exit 1' ERR
    
    # Esegui deploy
    create_backup
    stop_services
    create_directories
    deploy_backend
    deploy_frontend
    deploy_scripts
    
    # Verifica installazione
    if verify_installation; then
        start_services
        
        # Pulizia
        rm -rf "$TEMP_DIR"
        rm -f /tmp/armnas_backup_path
        
        log_success "🎉 Deploy completato con successo!"
        echo ""
        log_info "📋 Cosa è stato installato:"
        echo "  ✓ API di aggiornamento nel backend"
        echo "  ✓ Interfaccia web per aggiornamenti"
        echo "  ✓ Script per creare pacchetti"
        echo "  ✓ Server di esempio per distribuzione"
        echo "  ✓ Script di utilità"
        echo ""
        log_info "🌐 Accedi all'interfaccia web come amministratore"
        log_info "📖 Leggi UPDATE_SYSTEM_README.md per la documentazione completa"
        echo ""
        log_info "💡 Prossimi passi:"
        echo "  1. Ricompila il frontend se necessario:"
        echo "     cd $INSTALL_DIR/frontend && npm run build"
        echo "  2. Configura l'URL del server di aggiornamenti in:"
        echo "     $INSTALL_DIR/backend/api/routes/updates.py"
        echo "  3. Testa il sistema dalla pagina Aggiornamenti"
        
    else
        log_error "Verifica fallita, esecuzione rollback..."
        rollback
        exit 1
    fi
}

# Esegui se chiamato direttamente
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi