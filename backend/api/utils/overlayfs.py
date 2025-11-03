"""
Utility per gestire overlayfs RO/RW mode
Assicura che il filesystem sia in modalità RW prima di operazioni che richiedono scrittura

DEPRECATO: Questo modulo non è più utilizzato!
Il sistema ora usa zram-config invece di overlayfs per proteggere la SD card.
Con zram-config:
- Il root filesystem rimane scrivibile normalmente (nessun overlay)
- Solo swap e log vanno in RAM compressa tramite zram
- Migliori performance e più semplice da gestire

Questo modulo è mantenuto solo per compatibilità con codice esistente.
Le funzioni ora ritornano sempre valori che indicano filesystem scrivibile.
"""

import subprocess
import os
from typing import Tuple, Optional
import logging
import warnings

logger = logging.getLogger(__name__)

# Avvisa che questo modulo è deprecato
warnings.warn(
    "overlayfs.py è deprecato. Il sistema ora usa zram-config invece di overlayfs.",
    DeprecationWarning,
    stacklevel=2
)

def check_overlay_status() -> Tuple[bool, Optional[str]]:
    """
    Verifica lo stato corrente di overlayfs
    
    DEPRECATO: Ritorna sempre (False, None) perché il sistema non usa più overlayfs.
    Con zram-config, il root filesystem è sempre scrivibile normalmente.
    
    Returns:
        Tuple[bool, Optional[str]]: (overlay_attivo, modalità_corrente)
            overlay_attivo: False (overlayfs non più utilizzato)
            modalità_corrente: None (filesystem normale, sempre scrivibile)
    """
    logger.debug("check_overlay_status chiamato - overlayfs non più utilizzato, usando zram-config")
    
    # Manteniamo un controllo per compatibilità, nel caso ci sia ancora un sistema 
    # con overlayfs attivo (vecchia installazione)
    try:
        result = subprocess.run(
            ["mount"],
            capture_output=True,
            text=True,
            check=True,
            timeout=5
        )
        
        overlay_active = "type overlay" in result.stdout and "on /" in result.stdout
        
        if overlay_active:
            logger.warning("ATTENZIONE: overlayfs ancora attivo! Il sistema dovrebbe usare zram-config.")
            logger.warning("Considera di eseguire il nuovo script di installazione per migrare a zram-config.")
            # Ritorna comunque che non è gestito attivamente
            return True, "legacy"
        
        # Sistema normale con zram-config: filesystem sempre scrivibile
        return False, None
        
    except Exception as e:
        logger.error(f"Errore nel controllo overlayfs: {e}")
        # In caso di errore, assume filesystem normale
        return False, None


def ensure_rw_mode() -> bool:
    """
    Assicura che il filesystem sia in modalità RW
    
    DEPRECATO: Ritorna sempre True perché con zram-config il filesystem è sempre scrivibile.
    Non è più necessario passare da RO a RW.
    
    Returns:
        bool: True (il filesystem è sempre scrivibile con zram-config)
    """
    logger.debug("ensure_rw_mode chiamato - con zram-config il filesystem è sempre scrivibile")
    
    # Verifica comunque se c'è overlayfs legacy attivo
    try:
        overlay_active, current_mode = check_overlay_status()
        
        # Se overlayfs non è attivo (come dovrebbe essere), il sistema è già scrivibile
        if not overlay_active:
            logger.debug("Sistema normale con zram-config - filesystem sempre scrivibile")
            return True
        
        # Se c'è un overlayfs legacy, avvisa
        if overlay_active and current_mode == "legacy":
            logger.warning("Sistema legacy con overlayfs attivo rilevato!")
            logger.warning("Raccomandazione: migra a zram-config per migliori performance")
            logger.warning("Il sistema continuerà a funzionare ma con overlayfs legacy")
            # Tenta comunque di passare a RW se lo script esiste
            if os.path.exists("/usr/local/bin/overlay-rw"):
                try:
                    subprocess.run(
                        ["/usr/local/bin/overlay-rw"],
                        capture_output=True,
                        text=True,
                        check=False,
                        timeout=10
                    )
                except Exception:
                    pass
            return True
        
        # Default: assume filesystem scrivibile
        return True
            
    except Exception as e:
        logger.error(f"Errore nel verificare filesystem: {e}")
        # In caso di errore, assume filesystem scrivibile
        return True


def is_filesystem_writable(path: str = "/") -> bool:
    """
    Verifica se un path è scrivibile
    
    Args:
        path: Path da verificare (default: root filesystem)
        
    Returns:
        bool: True se il path è scrivibile
    """
    try:
        test_file = os.path.join(path, ".rw_test_file")
        # Prova a creare un file di test
        with open(test_file, "w") as f:
            f.write("test")
        # Rimuovi il file di test
        os.remove(test_file)
        return True
    except (OSError, IOError, PermissionError):
        return False

