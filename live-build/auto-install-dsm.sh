#!/bin/bash
# Script eseguito automaticamente al primo avvio con autologin
# Configurazione per live-build

set -euo pipefail

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Flag file per verificare se già eseguito
FLAG_FILE="/var/lib/armnas/auto-install-completed"

log() {
    echo -e "${GREEN}[AUTO-INSTALL]${NC} $1" >&2
    logger -t auto-install-dsm "$1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
    logger -t auto-install-dsm -p err "$1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
    logger -t auto-install-dsm -p warning "$1"
}

# Verifica se già eseguito
if [ -f "$FLAG_FILE" ]; then
    log "Installazione già completata in precedenza. Flag file trovato: $FLAG_FILE"
    log "Per rieseguire, rimuovi il flag file: rm -f $FLAG_FILE"
    exit 0
fi

log "Script di auto-installazione avviato..."
log "Attesa che il sistema sia completamente pronto..."

# Attendi che il filesystem sia montato correttamente
for i in {1..30}; do
    if mountpoint -q /root && [ -d /root ]; then
        break
    fi
    warn "Attesa mount /root... ($i/30)"
    sleep 1
done

# Attendi che il sistema di base sia pronto
sleep 3

# Crea directory per flag file
mkdir -p "$(dirname "$FLAG_FILE")"

# Funzione per cercare installer_dsm.sh
find_installer_script() {
    local script_paths=(
        "/root/installer_dsm.sh"
        "/opt/installer_dsm.sh"
        "$(find /root -name "installer_dsm.sh" -type f 2>/dev/null | head -1)"
        "$(find /opt -name "installer_dsm.sh" -type f 2>/dev/null | head -1)"
        "$(find / -name "installer_dsm.sh" -type f 2>/dev/null | head -1)"
    )
    
    for path in "${script_paths[@]}"; do
        if [ -n "$path" ] && [ -f "$path" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Cerca lo script installer con retry
INSTALLER_SCRIPT=""
for attempt in {1..10}; do
    log "Tentativo $attempt/10: ricerca installer_dsm.sh..."
    INSTALLER_SCRIPT=$(find_installer_script)
    
    if [ -n "$INSTALLER_SCRIPT" ]; then
        log "Trovato installer_dsm.sh: $INSTALLER_SCRIPT"
        break
    fi
    
    if [ $attempt -lt 10 ]; then
        warn "installer_dsm.sh non trovato, attesa 2 secondi..."
        sleep 2
    fi
done

if [ -z "$INSTALLER_SCRIPT" ] || [ ! -f "$INSTALLER_SCRIPT" ]; then
    error "Impossibile trovare installer_dsm.sh dopo 10 tentativi"
    error "Cerca manualmente con: find / -name installer_dsm.sh"
    echo "FAILED: installer_dsm.sh not found" > "$FLAG_FILE"
    exit 1
fi

# Renderlo eseguibile
chmod +x "$INSTALLER_SCRIPT" || {
    error "Impossibile rendere eseguibile: $INSTALLER_SCRIPT"
    exit 1
}

# Verifica che lo script sia realmente eseguibile
if [ ! -x "$INSTALLER_SCRIPT" ]; then
    error "Lo script non è eseguibile: $INSTALLER_SCRIPT"
    exit 1
fi

log "Esecuzione installer_dsm.sh (makeself) in modalità automatica..."
log "Questo processo potrebbe richiedere diversi minuti..."

# Verifica se è un archivio makeself
if ! file "$INSTALLER_SCRIPT" | grep -qi "makeself\|shell script"; then
    warn "Il file potrebbe non essere un archivio makeself valido"
    warn "$(file "$INSTALLER_SCRIPT")"
fi

# Directory temporanea per estrazione
EXTRACT_DIR="/tmp/armnas-installer-$$"
mkdir -p "$EXTRACT_DIR"

log "Estrazione archivio makeself in $EXTRACT_DIR..."

# Estrai il makeself esplicitamente invece di eseguirlo
# Makeself supporta --target per specificare dove estrarre
if "$INSTALLER_SCRIPT" --target "$EXTRACT_DIR" --noexec; then
    log "✓ Archivio estratto con successo"
else
    error "Impossibile estrarre archivio makeself"
    error "Provo metodo alternativo..."
    
    # Metodo alternativo: cerca il punto di separazione nell'archivio
    # I makeself hanno un marker che separa lo script dall'archivio tar.gz
    SKIP_LINES=$(grep -n -a "^__ARCHIVE_FOLLOWS__" "$INSTALLER_SCRIPT" 2>/dev/null | cut -d: -f1)
    
    if [ -n "$SKIP_LINES" ]; then
        SKIP_LINES=$((SKIP_LINES + 1))
        log "Trovato marker archivio alla riga $SKIP_LINES"
        log "Estrazione manuale dell'archivio..."
        
        tail -n +$SKIP_LINES "$INSTALLER_SCRIPT" | tar -xzf - -C "$EXTRACT_DIR" 2>/dev/null || {
            error "Estrazione manuale fallita"
            rm -rf "$EXTRACT_DIR"
            echo "FAILED: extraction failed" > "$FLAG_FILE"
            exit 1
        }
    else
        error "Impossibile trovare marker archivio nel makeself"
        rm -rf "$EXTRACT_DIR"
        echo "FAILED: invalid makeself" > "$FLAG_FILE"
        exit 1
    fi
fi

# Cerca lo script principale nell'archivio estratto
# Tipicamente i makeself eseguono uno script chiamato dal parametro --startup
MAIN_SCRIPT=""

# Cerca possibili script principali
for script_name in "install.sh" "setup.sh" "installer.sh" "main.sh" "run.sh"; do
    if [ -f "$EXTRACT_DIR/$script_name" ]; then
        MAIN_SCRIPT="$EXTRACT_DIR/$script_name"
        log "Trovato script principale: $script_name"
        break
    fi
done

# Se non trovato, cerca il primo .sh eseguibile
if [ -z "$MAIN_SCRIPT" ]; then
    MAIN_SCRIPT=$(find "$EXTRACT_DIR" -maxdepth 2 -name "*.sh" -type f -executable 2>/dev/null | head -1)
    if [ -n "$MAIN_SCRIPT" ]; then
        log "Trovato script: $(basename "$MAIN_SCRIPT")"
    fi
fi

# Se ancora non trovato, lista il contenuto
if [ -z "$MAIN_SCRIPT" ]; then
    error "Nessuno script principale trovato nell'archivio"
    error "Contenuto estratto:"
    ls -la "$EXTRACT_DIR" >&2
    
    # Prova a eseguire direttamente il makeself con --auto
    log "Fallback: esecuzione diretta del makeself..."
    cd "$(dirname "$INSTALLER_SCRIPT")" || exit 1
    
    if ! "$INSTALLER_SCRIPT" --auto; then
        INSTALL_EXIT_CODE=$?
        error "Installazione fallita con codice: $INSTALL_EXIT_CODE"
        rm -rf "$EXTRACT_DIR"
        echo "FAILED: exit code $INSTALL_EXIT_CODE" > "$FLAG_FILE"
        exit $INSTALL_EXIT_CODE
    fi
    
    INSTALL_EXIT_CODE=0
else
    # Esegui lo script principale trovato
    log "Esecuzione: $(basename "$MAIN_SCRIPT")"
    chmod +x "$MAIN_SCRIPT"
    
    cd "$EXTRACT_DIR" || {
        error "Impossibile cambiare directory: $EXTRACT_DIR"
        rm -rf "$EXTRACT_DIR"
        exit 1
    }
    
    # Esegui con parametro --auto se supportato
    if ! bash "$MAIN_SCRIPT" --auto 2>&1 | tee /var/log/armnas-install.log; then
        INSTALL_EXIT_CODE=$?
        error "Installazione fallita con codice: $INSTALL_EXIT_CODE"
        log "Log salvato in: /var/log/armnas-install.log"
        rm -rf "$EXTRACT_DIR"
        echo "FAILED: exit code $INSTALL_EXIT_CODE" > "$FLAG_FILE"
        exit $INSTALL_EXIT_CODE
    fi
    
    INSTALL_EXIT_CODE=0
fi

# Pulizia directory temporanea
log "Pulizia file temporanei..."
rm -rf "$EXTRACT_DIR"

if [ $INSTALL_EXIT_CODE -eq 0 ]; then
    log "✓ Installazione completata con successo!"
    
    # Crea flag file per indicare completamento
    echo "COMPLETED: $(date -Iseconds)" > "$FLAG_FILE"
    
    # Disattiva l'autologin
    log "Disattivazione autologin..."
    
    # Usa lo script di disabilitazione se esiste
    if [ -f /usr/local/bin/disable-autologin.sh ]; then
        /usr/local/bin/disable-autologin.sh || {
            warn "Errore nell'esecuzione di disable-autologin.sh, tentativo manuale..."
        }
    fi
    
    # Rimuovi autologin per getty (fallback manuale)
    if [ -f /etc/systemd/system/getty@tty1.service.d/autologin.conf ]; then
        rm -f /etc/systemd/system/getty@tty1.service.d/autologin.conf
        systemctl daemon-reload || true
    fi
    
    # Rimuovi autologin da /etc/inittab se esiste
    if command -v inittab >/dev/null 2>&1; then
        sed -i 's/::once:\/bin\/bash/::respawn:\/sbin\/getty 38400 tty1/g' /etc/inittab 2>/dev/null || true
    fi
    
    # Disattiva autostart per questo script
    find /home -name ".profile" -type f 2>/dev/null | while read -r profile; do
        sed -i '/auto-install-dsm.sh/d' "$profile" 2>/dev/null || true
    done
    
    if [ -f /root/.profile ]; then
        sed -i '/auto-install-dsm.sh/d' /root/.profile 2>/dev/null || true
    fi
    
    # Disabilita il servizio per evitare riesecuzione
    systemctl disable auto-install-dsm.service 2>/dev/null || true
    
    log "Autologin disattivato"
    log "Il sistema verrà riavviato automaticamente tra 5 secondi per applicare le modifiche..."
    sleep 5
    
    # Riavvia il sistema
    log "Riavvio del sistema..."
    systemctl reboot || reboot || {
        warn "Errore nel comando reboot, prova manualmente"
    }
else
    error "Installazione fallita con codice: $INSTALL_EXIT_CODE"
    echo "FAILED: exit code $INSTALL_EXIT_CODE" > "$FLAG_FILE"
    exit $INSTALL_EXIT_CODE
fi

exit 0

