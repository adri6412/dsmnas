"""
Route per operazioni di sistema (overlayfs, stato sistema, ecc.)
"""

from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Dict, Optional, Any, List
import subprocess
import logging
import platform
import psutil
from datetime import datetime, timedelta
from ..auth import get_current_admin
from ..utils.overlayfs import check_overlay_status, ensure_rw_mode, is_filesystem_writable

router = APIRouter()
logger = logging.getLogger(__name__)

class OverlayModeRequest(BaseModel):
    mode: str  # "ro" or "rw"

class ServiceAction(BaseModel):
    service_name: str

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

@router.get("/info", response_model=Dict[str, Any])
async def get_system_info(current_admin = Depends(get_current_admin)):
    """
    Ottiene informazioni generali sul sistema
    """
    try:
        # Ottieni uptime
        boot_time = datetime.fromtimestamp(psutil.boot_time())
        uptime_delta = datetime.now() - boot_time
        days = uptime_delta.days
        hours, remainder = divmod(uptime_delta.seconds, 3600)
        minutes, _ = divmod(remainder, 60)
        uptime_str = f"{days}d {hours}h {minutes}m" if days > 0 else f"{hours}h {minutes}m"
        
        # Ottieni hostname
        hostname = platform.node()
        
        # Ottieni info OS
        os_info = f"{platform.system()} {platform.release()}"
        
        # Ottieni kernel
        kernel = platform.release()
        
        # Ottieni info memoria
        mem = psutil.virtual_memory()
        mem_total_gb = round(mem.total / (1024**3), 1)
        mem_used_gb = round(mem.used / (1024**3), 1)
        mem_percent = mem.percent
        
        return {
            "hostname": hostname,
            "os": os_info,
            "kernel": kernel,
            "uptime": uptime_str,
            "memory": {
                "total_gb": mem_total_gb,
                "used_gb": mem_used_gb,
                "percent": mem_percent
            }
        }
    except Exception as e:
        logger.error(f"Errore nel recupero informazioni sistema: {e}")
        raise HTTPException(status_code=500, detail=f"Errore: {str(e)}")

@router.get("/services", response_model=List[Dict[str, Any]])
async def get_services_status(current_admin = Depends(get_current_admin)):
    """
    Ottiene lo stato dei servizi principali del sistema
    """
    try:
        # Lista servizi da monitorare
        services_to_check = [
            "armnas-backend",
            "nginx",
            "smbd",
            "vsftpd",
            "ssh",
            "docker"
        ]
        
        services_status = []
        
        for service_name in services_to_check:
            try:
                # Verifica se attivo
                is_active = subprocess.run(
                    ["systemctl", "is-active", service_name],
                    capture_output=True,
                    text=True,
                    check=False
                ).returncode == 0
                
                # Verifica se abilitato
                is_enabled = subprocess.run(
                    ["systemctl", "is-enabled", service_name],
                    capture_output=True,
                    text=True,
                    check=False
                ).returncode == 0
                
                services_status.append({
                    "name": service_name,
                    "active": is_active,
                    "enabled": is_enabled,
                    "status": "running" if is_active else "stopped"
                })
            except Exception as e:
                logger.warning(f"Errore nel controllo servizio {service_name}: {e}")
                services_status.append({
                    "name": service_name,
                    "active": False,
                    "enabled": False,
                    "status": "unknown"
                })
        
        return services_status
    except Exception as e:
        logger.error(f"Errore nel recupero stato servizi: {e}")
        raise HTTPException(status_code=500, detail=f"Errore: {str(e)}")

@router.post("/service/restart")
async def restart_service(action: ServiceAction, current_admin = Depends(get_current_admin)):
    """
    Riavvia un servizio
    """
    try:
        result = subprocess.run(
            ["systemctl", "restart", action.service_name],
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode == 0:
            return {"status": "success", "message": f"Servizio {action.service_name} riavviato"}
        else:
            raise HTTPException(status_code=500, detail=result.stderr or "Errore nel riavvio del servizio")
    except Exception as e:
        logger.error(f"Errore nel riavvio servizio {action.service_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/service/start")
async def start_service(action: ServiceAction, current_admin = Depends(get_current_admin)):
    """
    Avvia un servizio
    """
    try:
        result = subprocess.run(
            ["systemctl", "start", action.service_name],
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode == 0:
            return {"status": "success", "message": f"Servizio {action.service_name} avviato"}
        else:
            raise HTTPException(status_code=500, detail=result.stderr or "Errore nell'avvio del servizio")
    except Exception as e:
        logger.error(f"Errore nell'avvio servizio {action.service_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/service/stop")
async def stop_service(action: ServiceAction, current_admin = Depends(get_current_admin)):
    """
    Ferma un servizio
    """
    try:
        result = subprocess.run(
            ["systemctl", "stop", action.service_name],
            capture_output=True,
            text=True,
            check=False
        )
        
        if result.returncode == 0:
            return {"status": "success", "message": f"Servizio {action.service_name} fermato"}
        else:
            raise HTTPException(status_code=500, detail=result.stderr or "Errore nell'arresto del servizio")
    except Exception as e:
        logger.error(f"Errore nell'arresto servizio {action.service_name}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

