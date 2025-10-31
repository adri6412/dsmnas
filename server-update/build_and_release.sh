#!/bin/bash

# Script per automatizzare il processo di build e rilascio di ArmNAS
# Compila il frontend, crea il pacchetto di aggiornamento e lo pubblica

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION=""
CHANGELOG=""
CRITICAL=false
UPLOAD_TO_SERVER=false
SERVER_URL=""
AUTH_TOKEN=""

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

show_help() {
    cat << EOF
🚀 ArmNAS Build & Release Script

Utilizzo: $0 --version <version> [opzioni]

Opzioni obbligatorie:
  --version <version>           Versione da rilasciare (es: 1.2.3)

Opzioni facoltative:
  --changelog <message>         Messaggio di changelog (può essere ripetuto)
  --critical                    Marca come aggiornamento critico
  --upload                      Carica sul server di aggiornamenti
  --server <url>                URL del server di aggiornamenti
  --token <token>               Token di autenticazione per upload
  --help                        Mostra questo messaggio

Esempi:
  $0 --version 1.2.3 --changelog "Nuove funzionalità" --changelog "Bug fix"
  $0 --version 1.2.4 --critical --upload --server https://updates.armnas.com --token abc123

Processo:
  1. Compila il frontend Vue.js
  2. Crea il pacchetto di aggiornamento .run
  3. Testa il pacchetto
  4. (Opzionale) Carica sul server di distribuzione

EOF
}

# Parse argomenti
while [[ $# -gt 0 ]]; do
    case $1 in
        --version)
            VERSION="$2"
            shift 2
            ;;
        --changelog)
            if [[ -z "$CHANGELOG" ]]; then
                CHANGELOG="$2"
            else
                CHANGELOG="$CHANGELOG,$2"
            fi
            shift 2
            ;;
        --critical)
            CRITICAL=true
            shift
            ;;
        --upload)
            UPLOAD_TO_SERVER=true
            shift
            ;;
        --server)
            SERVER_URL="$2"
            shift 2
            ;;
        --token)
            AUTH_TOKEN="$2"
            shift 2
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Opzione sconosciuta: $1"
            show_help
            exit 1
            ;;
    esac
done

# Verifica argomenti obbligatori
if [[ -z "$VERSION" ]]; then
    log_error "Versione richiesta"
    show_help
    exit 1
fi

# Verifica formato versione
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9]+)?$ ]]; then
    log_error "Formato versione non valido. Usa: X.Y.Z o X.Y.Z-suffix"
    exit 1
fi

log_info "🚀 Avvio build e rilascio ArmNAS v$VERSION"

# 1. Verifica prerequisiti
log_info "🔍 Verifica prerequisiti..."

# Verifica Node.js e npm
if ! command -v node &> /dev/null; then
    log_error "Node.js non trovato. Installare Node.js per continuare."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    log_error "npm non trovato. Installare npm per continuare."
    exit 1
fi

# Verifica Python
if ! command -v python3 &> /dev/null; then
    log_error "Python 3 non trovato. Installare Python 3 per continuare."
    exit 1
fi

log_success "Prerequisiti verificati"

# 2. Compila il frontend
log_info "🌐 Compilazione frontend..."

cd "$SCRIPT_DIR/frontend"

# Installa dipendenze se necessario
if [[ ! -d "node_modules" ]]; then
    log_info "Installazione dipendenze npm..."
    npm install
fi

# Build di produzione
log_info "Build di produzione..."
npm run build

if [[ $? -ne 0 ]]; then
    log_error "Errore nella compilazione del frontend"
    exit 1
fi

log_success "Frontend compilato con successo"

# 3. Aggiorna la versione nel backend
log_info "📝 Aggiornamento versione nel backend..."

cd "$SCRIPT_DIR"

# Aggiorna la versione nel file di configurazione
sed -i "s/\"current_version\": \"[^\"]*\"/\"current_version\": \"$VERSION\"/" backend/api/routes/updates.py

# Aggiorna la versione nel main.py
sed -i "s/version=\"[^\"]*\"/version=\"$VERSION\"/" backend/main.py

log_success "Versione aggiornata a $VERSION"

# 4. Crea il pacchetto di aggiornamento
log_info "📦 Creazione pacchetto di aggiornamento..."

# Prepara argomenti per lo script di creazione
CREATE_ARGS="$VERSION --source $SCRIPT_DIR --output $SCRIPT_DIR/updates"

if [[ -n "$CHANGELOG" ]]; then
    # Converte la stringa separata da virgole in argomenti multipli
    IFS=',' read -ra CHANGELOG_ARRAY <<< "$CHANGELOG"
    for item in "${CHANGELOG_ARRAY[@]}"; do
        CREATE_ARGS="$CREATE_ARGS --changelog \"$item\""
    done
fi

if [[ "$CRITICAL" == true ]]; then
    CREATE_ARGS="$CREATE_ARGS --critical"
fi

# Esegui lo script di creazione
eval "python3 create_update_package_fixed.py $CREATE_ARGS"

if [[ $? -ne 0 ]]; then
    log_error "Errore nella creazione del pacchetto"
    exit 1
fi

PACKAGE_FILE="$SCRIPT_DIR/updates/armnas_update_v$VERSION.run"

if [[ ! -f "$PACKAGE_FILE" ]]; then
    log_error "Pacchetto non trovato: $PACKAGE_FILE"
    exit 1
fi

log_success "Pacchetto creato: $PACKAGE_FILE"

# 5. Testa il pacchetto
log_info "🧪 Test del pacchetto..."

./manage_updates.sh test "$PACKAGE_FILE"

if [[ $? -ne 0 ]]; then
    log_error "Test del pacchetto fallito"
    exit 1
fi

log_success "Test del pacchetto completato"

# 6. Mostra informazioni del pacchetto
log_info "📊 Informazioni pacchetto:"
PACKAGE_SIZE=$(du -h "$PACKAGE_FILE" | cut -f1)
echo "  📁 File: $(basename "$PACKAGE_FILE")"
echo "  📏 Dimensione: $PACKAGE_SIZE"

INFO_FILE="${PACKAGE_FILE}.info"
if [[ -f "$INFO_FILE" ]]; then
    CHECKSUM=$(grep -o '"checksum": "[^"]*"' "$INFO_FILE" | cut -d'"' -f4)
    echo "  🔐 Checksum: ${CHECKSUM:0:16}..."
fi

# 7. Upload al server (se richiesto)
if [[ "$UPLOAD_TO_SERVER" == true ]]; then
    log_info "☁️  Upload al server di aggiornamenti..."
    
    if [[ -z "$SERVER_URL" ]]; then
        log_error "URL del server richiesto per l'upload"
        exit 1
    fi
    
    if [[ -z "$AUTH_TOKEN" ]]; then
        log_error "Token di autenticazione richiesto per l'upload"
        exit 1
    fi
    
    # Upload del file
    UPLOAD_URL="$SERVER_URL/api/v1/upload"
    
    log_info "Upload a: $UPLOAD_URL"
    
    RESPONSE=$(curl -s -w "%{http_code}" -X POST \
        -H "Authorization: Bearer $AUTH_TOKEN" \
        -F "file=@$PACKAGE_FILE" \
        "$UPLOAD_URL")
    
    HTTP_CODE="${RESPONSE: -3}"
    RESPONSE_BODY="${RESPONSE%???}"
    
    if [[ "$HTTP_CODE" == "200" ]]; then
        log_success "Upload completato con successo"
        echo "  Risposta server: $RESPONSE_BODY"
    else
        log_error "Errore nell'upload (HTTP $HTTP_CODE)"
        echo "  Risposta server: $RESPONSE_BODY"
        exit 1
    fi
fi

# 8. Crea tag Git (se in un repository Git)
if [[ -d ".git" ]]; then
    log_info "🏷️  Creazione tag Git..."
    
    # Verifica se ci sono modifiche non committate
    if [[ -n $(git status --porcelain) ]]; then
        log_warning "Ci sono modifiche non committate. Commit prima di creare il tag."
        
        read -p "Vuoi committare le modifiche automaticamente? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git add .
            git commit -m "Release v$VERSION"
        else
            log_warning "Tag non creato a causa di modifiche non committate"
        fi
    fi
    
    if [[ -z $(git status --porcelain) ]]; then
        # Crea il tag
        TAG_MESSAGE="Release v$VERSION"
        if [[ -n "$CHANGELOG" ]]; then
            TAG_MESSAGE="$TAG_MESSAGE\n\nChangelog:\n${CHANGELOG//,/\n- }"
        fi
        
        git tag -a "v$VERSION" -m "$TAG_MESSAGE"
        log_success "Tag v$VERSION creato"
        
        read -p "Vuoi pushare il tag al repository remoto? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin "v$VERSION"
            log_success "Tag pushato al repository remoto"
        fi
    fi
fi

# 9. Riepilogo finale
log_success "🎉 Build e rilascio completati!"
echo ""
echo "📋 Riepilogo:"
echo "  🏷️  Versione: $VERSION"
echo "  📦 Pacchetto: $PACKAGE_FILE"
echo "  📏 Dimensione: $PACKAGE_SIZE"
if [[ "$CRITICAL" == true ]]; then
    echo "  ⚠️  Aggiornamento CRITICO"
fi
if [[ -n "$CHANGELOG" ]]; then
    echo "  📝 Changelog:"
    IFS=',' read -ra CHANGELOG_ARRAY <<< "$CHANGELOG"
    for item in "${CHANGELOG_ARRAY[@]}"; do
        echo "     - $item"
    done
fi
if [[ "$UPLOAD_TO_SERVER" == true ]]; then
    echo "  ☁️  Caricato sul server: $SERVER_URL"
fi

echo ""
log_info "💡 Prossimi passi:"
echo "  1. Testa il pacchetto in un ambiente di staging"
echo "  2. Notifica gli utenti dell'aggiornamento disponibile"
echo "  3. Monitora i log per eventuali problemi"

if [[ "$UPLOAD_TO_SERVER" == false ]]; then
    echo "  4. Carica manualmente il pacchetto sul server:"
    echo "     curl -X POST -H \"Authorization: Bearer YOUR_TOKEN\" \\"
    echo "          -F \"file=@$PACKAGE_FILE\" \\"
    echo "          https://your-server.com/api/v1/upload"
fi