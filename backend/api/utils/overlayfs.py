"""
Utility per gestire overlayfs RO/RW mode
Assicura che il filesystem sia in modalità RW prima di operazioni che richiedono scrittura
"""

import subprocess
import os
from typing import Tuple, Optional
import logging

logger = logging.getLogger(__name__)

def check_overlay_status() -> Tuple[bool, Optional[str]]:
    """
    Verifica lo stato corrente di overlayfs
    
    Returns:
        Tuple[bool, Optional[str]]: (overlay_attivo, modalità_corrente)
            overlay_attivo: True se overlayfs è attivo
            modalità_corrente: "ro" o "rw" o None se overlayfs non attivo
    """
    try:
        # Verifica se overlayfs è attivo
        result = subprocess.run(
            ["mount"],
            capture_output=True,
            text=True,
            check=True
        )
        
        overlay_active = "type overlay" in result.stdout and "on /" in result.stdout
        
        if not overlay_active:
            return False, None
        
        # Verifica modalità corrente
        # Se l'upper directory è tmpfs, siamo in RO
        # Se è bind mount dalla SD, siamo in RW
        upper_path = "/overlay/upper"
        if os.path.exists(upper_path):
            try:
                # Usa findmnt per vedere dove è montato /overlay/upper
                findmnt_result = subprocess.run(
                    ["findmnt", "-n", "-o", "SOURCE", upper_path],
                    capture_output=True,
                    text=True,
                    check=False
                )
                
                if findmnt_result.returncode == 0:
                    source = findmnt_result.stdout.strip()
                    if "tmpfs" in source:
                        return True, "ro"
                    elif "upper-sd" in source or "/media/root-ro" in source:
                        return True, "rw"
            except Exception as e:
                logger.warning(f"Errore nel verificare modalità overlayfs: {e}")
        
        # Fallback: verifica file di stato
        state_file = "/var/lib/overlay-state"
        if os.path.exists(state_file):
            try:
                with open(state_file, "r") as f:
                    mode = f.read().strip()
                    if mode in ["ro", "rw"]:
                        return True, mode
            except Exception:
                pass
        
        # Default: assume RO se overlayfs è attivo
        return True, "ro"
        
    except Exception as e:
        logger.error(f"Errore nel controllo overlayfs: {e}")
        return False, None


def ensure_rw_mode() -> bool:
    """
    Assicura che il filesystem sia in modalità RW
    Se necessario, passa da RO a RW
    
    Returns:
        bool: True se il sistema è ora in RW (o overlayfs non attivo)
              False se non è stato possibile passare a RW
    """
    try:
        overlay_active, current_mode = check_overlay_status()
        
        # Se overlayfs non è attivo, il sistema è già scrivibile
        if not overlay_active:
            logger.debug("Overlayfs non attivo - filesystem già scrivibile")
            return True
        
        # Se siamo già in RW, non serve fare nulla
        if current_mode == "rw":
            logger.debug("Sistema già in modalità RW")
            return True
        
        # Passa a modalità RW
        logger.info("Passaggio a modalità RW per permettere scritture permanenti...")
        result = subprocess.run(
            ["/usr/local/bin/overlay-rw"],
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode == 0:
            logger.info("Sistema passato a modalità RW con successo")
            return True
        else:
            logger.error(f"Errore nel passare a modalità RW: {result.stderr}")
            return False
            
    except Exception as e:
        logger.error(f"Errore nel verificare/passare a modalità RW: {e}")
        return False


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

