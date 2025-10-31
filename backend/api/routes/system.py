"""
Route per operazioni di sistema (overlayfs, stato sistema, ecc.)
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Dict, Optional, Any
import subprocess
import logging
from ..auth import get_current_admin
from ..utils.overlayfs import check_overlay_status, ensure_rw_mode, is_filesystem_writable

router = APIRouter()
logger = logging.getLogger(__name__)

class OverlayModeRequest(BaseModel):
    mode: str  # "ro" or "rw"

@router.get("/overlayfs/status", response_model=Dict[str, Any])
async def get_overlayfs_status(current_admin = Depends(get_current_admin)):
    """
    Ottiene lo stato corrente di overlayfs
    """
    try:
        overlay_active, current_mode = check_overlay_status()
        
        # Ottieni informazioni dettagliate tramite overlay-status
        status_info = {}
        try:
            result = subprocess.run(
                ["/usr/local/bin/overlay-status"],
                capture_output=True,
                text=True,
                check=False
            )
            status_info["details"] = result.stdout
        except Exception:
            pass
        
        return {
            "overlay_active": overlay_active,
            "current_mode": current_mode,
            "writable": is_filesystem_writable("/") if overlay_active else True,
            "status_details": status_info.get("details", "")
        }
    except Exception as e:
        logger.error(f"Errore nel recupero dello stato overlayfs: {e}")
        raise HTTPException(status_code=500, detail=f"Errore nel recupero dello stato: {str(e)}")

@router.post("/overlayfs/mode", response_model=Dict[str, str])
async def set_overlayfs_mode(request: OverlayModeRequest, current_admin = Depends(get_current_admin)):
    """
    Cambia la modalità overlayfs (RO o RW)
    
    Args:
        request: Richiesta con modalità desiderata ("ro" o "rw")
    """
    if request.mode not in ["ro", "rw"]:
        raise HTTPException(status_code=400, detail="Modalità non valida. Usa 'ro' o 'rw'")
    
    try:
        # Esegui il comando appropriato
        if request.mode == "rw":
            command = "/usr/local/bin/overlay-rw"
        else:
            command = "/usr/local/bin/overlay-ro"
        
        result = subprocess.run(
            [command],
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode == 0:
            # Verifica lo stato dopo il cambio
            overlay_active, new_mode = check_overlay_status()
            return {
                "status": "success",
                "message": f"Sistema passato a modalità {request.mode.upper()}",
                "current_mode": new_mode or request.mode,
                "output": result.stdout
            }
        else:
            raise HTTPException(
                status_code=500,
                detail=f"Errore nel cambio modalità: {result.stderr or result.stdout}"
            )
            
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Errore nel cambio modalità overlayfs: {e}")
        raise HTTPException(status_code=500, detail=f"Errore nel cambio modalità: {str(e)}")

