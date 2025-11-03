#!/bin/bash
# Script di auto-aggiornamento ArmNAS
# Viene eseguito all'avvio del sistema per cercare e installare aggiornamenti pending

set -e

# Directory dove vengono caricati i file .run da installare
UPDATE_DIR="/opt/armnas/pending-updates"
LOG_FILE="/var/log/armnas-auto-update.log"
LOCK_FILE="/var/run/armnas-auto-update.lock"

# Funzione per logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Funzione per pulizia e uscita
cleanup() {
    rm -f "$LOCK_FILE"
    exit $1
}

# Trap per gestire interruzioni
trap 'cleanup 1' INT TERM

# Verifica privilegi root
if [[ $EUID -ne 0 ]]; then
    log "ERRORE: Questo script deve essere eseguito come root"
    exit 1
fi

# Crea lock file per evitare esecuzioni multiple
if [ -f "$LOCK_FILE" ]; then
    log "Un'altra istanza dello script è già in esecuzione"
    exit 0
fi

touch "$LOCK_FILE"

log "===== Avvio controllo aggiornamenti automatici ====="

# Crea directory se non esiste
if [ ! -d "$UPDATE_DIR" ]; then
    log "Creazione directory $UPDATE_DIR"
    mkdir -p "$UPDATE_DIR"
    chmod 755 "$UPDATE_DIR"
fi

# Cerca file .run nella directory
UPDATE_FILES=$(find "$UPDATE_DIR" -maxdepth 1 -name "*.run" -type f 2>/dev/null || true)

if [ -z "$UPDATE_FILES" ]; then
    log "Nessun aggiornamento in sospeso trovato"
    cleanup 0
fi

# Conta i file trovati
UPDATE_COUNT=$(echo "$UPDATE_FILES" | wc -l)
log "Trovati $UPDATE_COUNT file di aggiornamento:"
echo "$UPDATE_FILES" | while read -r file; do
    log "  - $(basename "$file")"
done

# Processa ogni file .run trovato
echo "$UPDATE_FILES" | while read -r UPDATE_FILE; do
    if [ ! -f "$UPDATE_FILE" ]; then
        continue
    fi
    
    FILE_NAME=$(basename "$UPDATE_FILE")
    log "========================================="
    log "Installazione aggiornamento: $FILE_NAME"
    log "========================================="
    
    # Verifica che sia un file makeself/eseguibile
    if ! file "$UPDATE_FILE" | grep -q "sh"; then
        log "ERRORE: $FILE_NAME non sembra essere un file di aggiornamento valido"
        log "Spostamento in $UPDATE_DIR/failed/"
        mkdir -p "$UPDATE_DIR/failed"
        mv "$UPDATE_FILE" "$UPDATE_DIR/failed/" 2>/dev/null || true
        continue
    fi
    
    # Rendi eseguibile
    chmod +x "$UPDATE_FILE"
    
    # Esegui l'aggiornamento in modalità automatica
    log "Esecuzione aggiornamento $FILE_NAME..."
    
    if bash "$UPDATE_FILE" --auto 2>&1 | tee -a "$LOG_FILE"; then
        log "✓ Aggiornamento $FILE_NAME completato con successo"
        
        # Cancella il file dopo l'installazione riuscita
        log "Rimozione file di aggiornamento $FILE_NAME"
        rm -f "$UPDATE_FILE"
        
        # Crea flag di aggiornamento completato
        echo "$(date -Iseconds)|$FILE_NAME|SUCCESS" >> "$UPDATE_DIR/update-history.log"
        
    else
        EXIT_CODE=$?
        log "✗ ERRORE durante l'installazione di $FILE_NAME (exit code: $EXIT_CODE)"
        
        # Sposta il file in una directory di errori
        mkdir -p "$UPDATE_DIR/failed"
        mv "$UPDATE_FILE" "$UPDATE_DIR/failed/" 2>/dev/null || true
        log "File spostato in $UPDATE_DIR/failed/"
        
        # Registra il fallimento
        echo "$(date -Iseconds)|$FILE_NAME|FAILED|$EXIT_CODE" >> "$UPDATE_DIR/update-history.log"
    fi
    
    log "========================================="
done

# Controlla se ci sono ancora file .run
REMAINING=$(find "$UPDATE_DIR" -maxdepth 1 -name "*.run" -type f 2>/dev/null | wc -l)

if [ "$REMAINING" -eq 0 ]; then
    log "✓ Tutti gli aggiornamenti sono stati processati"
else
    log "⚠ Rimangono $REMAINING file di aggiornamento non processati"
fi

log "===== Controllo aggiornamenti completato ====="

cleanup 0

