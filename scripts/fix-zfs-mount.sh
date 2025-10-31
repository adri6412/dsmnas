#!/bin/bash
# Script per diagnosticare e risolvere problemi di montaggio ZFS
# Uso: sudo ./fix-zfs-mount.sh

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[FIX-ZFS]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

# Verifica privilegi root
if [ "$EUID" -ne 0 ]; then
    error "Questo script deve essere eseguito come root (usa sudo)"
    exit 1
fi

log "=== DIAGNOSI POOL ZFS E MONTAGGIO /storage ==="
echo ""

# 1. Verifica se /storage è montato
info "1. Verifica montaggio /storage..."
if mountpoint -q /storage 2>/dev/null; then
    warn "/storage è attualmente MONTATO"
    mount | grep /storage
    echo ""
    
    # Mostra cosa è montato
    FS_TYPE=$(findmnt -n -o FSTYPE /storage 2>/dev/null || echo "unknown")
    SOURCE=$(findmnt -n -o SOURCE /storage 2>/dev/null || echo "unknown")
    info "Tipo filesystem: $FS_TYPE"
    info "Sorgente: $SOURCE"
    echo ""
else
    log "/storage NON è montato"
fi

# 2. Verifica pool ZFS esistenti
info "2. Verifica pool ZFS esistenti..."
if command -v zpool >/dev/null 2>&1; then
    if zpool list 2>/dev/null | grep -q "storage"; then
        warn "Pool ZFS 'storage' ESISTE GIÀ:"
        zpool list storage
        echo ""
        zpool status storage
        echo ""
    else
        log "Nessun pool ZFS 'storage' trovato"
    fi
    
    # Mostra tutti i pool
    if zpool list 2>/dev/null | tail -n +2 | grep -q .; then
        info "Pool ZFS esistenti:"
        zpool list
        echo ""
    fi
else
    error "Comando 'zpool' non trovato. ZFS non è installato?"
    exit 1
fi

# 3. Verifica se ci sono pool da importare
info "3. Verifica pool ZFS da importare..."
if zpool import 2>/dev/null | grep -q "pool:"; then
    warn "Pool ZFS disponibili per importazione:"
    zpool import
    echo ""
else
    log "Nessun pool da importare"
fi

echo ""
log "=== OPZIONI DI RISOLUZIONE ==="
echo ""

# Chiedi all'utente cosa fare
echo "Seleziona un'azione:"
echo "1) Smonta /storage (se montato)"
echo "2) Distruggi pool ZFS 'storage' esistente (ATTENZIONE: cancella dati!)"
echo "3) Esporta pool ZFS 'storage' (mantiene dati)"
echo "4) Importa pool ZFS esistente"
echo "5) Forza smontaggio e distruzione pool (ATTENZIONE: cancella tutto!)"
echo "6) Mostra solo informazioni (già fatto)"
echo "0) Esci senza fare nulla"
echo ""

read -p "Scegli un'opzione [0-6]: " choice

case $choice in
    1)
        log "Smontaggio /storage..."
        if mountpoint -q /storage 2>/dev/null; then
            umount /storage || {
                warn "Smontaggio normale fallito, provo con -l (lazy unmount)..."
                umount -l /storage || {
                    error "Impossibile smontare /storage"
                    exit 1
                }
            }
            log "✓ /storage smontato con successo"
        else
            log "/storage non è montato, niente da fare"
        fi
        ;;
    
    2)
        warn "ATTENZIONE: Questa operazione CANCELLERÀ tutti i dati nel pool!"
        read -p "Sei sicuro? Digita 'YES' per confermare: " confirm
        if [ "$confirm" = "YES" ]; then
            log "Distruzione pool 'storage'..."
            
            # Prova a esportare prima
            zpool export storage 2>/dev/null || true
            
            # Poi distruggi
            if zpool destroy storage 2>/dev/null; then
                log "✓ Pool 'storage' distrutto"
            else
                warn "Pool non esiste o già distrutto"
            fi
        else
            log "Operazione annullata"
        fi
        ;;
    
    3)
        log "Esportazione pool 'storage'..."
        if zpool export storage 2>/dev/null; then
            log "✓ Pool 'storage' esportato (può essere reimportato successivamente)"
        else
            error "Impossibile esportare il pool"
            exit 1
        fi
        ;;
    
    4)
        log "Importazione pool..."
        info "Pool disponibili:"
        zpool import
        echo ""
        read -p "Inserisci il nome del pool da importare (o ENTER per 'storage'): " pool_name
        pool_name=${pool_name:-storage}
        
        if zpool import "$pool_name" 2>/dev/null; then
            log "✓ Pool '$pool_name' importato con successo"
        else
            error "Impossibile importare il pool '$pool_name'"
            exit 1
        fi
        ;;
    
    5)
        warn "ATTENZIONE: Questa operazione CANCELLERÀ tutto forzatamente!"
        read -p "Sei ASSOLUTAMENTE sicuro? Digita 'DELETE ALL' per confermare: " confirm
        if [ "$confirm" = "DELETE ALL" ]; then
            log "Smontaggio forzato di /storage..."
            umount -f /storage 2>/dev/null || true
            umount -l /storage 2>/dev/null || true
            
            log "Esportazione forzata pool..."
            zpool export -f storage 2>/dev/null || true
            
            log "Distruzione forzata pool..."
            zpool destroy -f storage 2>/dev/null || true
            
            log "✓ Operazione di pulizia forzata completata"
        else
            log "Operazione annullata"
        fi
        ;;
    
    6)
        log "Visualizzazione completata. Nessuna modifica effettuata."
        ;;
    
    0)
        log "Uscita senza modifiche"
        exit 0
        ;;
    
    *)
        error "Opzione non valida"
        exit 1
        ;;
esac

echo ""
log "=== STATO FINALE ==="
echo ""

# Verifica stato finale
if mountpoint -q /storage 2>/dev/null; then
    info "/storage è montato:"
    mount | grep /storage
else
    log "/storage NON è montato"
fi

echo ""

if zpool list storage 2>/dev/null; then
    info "Pool 'storage' esiste:"
    zpool list storage
else
    log "Pool 'storage' non esiste"
fi

echo ""
log "Operazione completata!"

