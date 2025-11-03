"""
API Routes per la gestione degli aggiornamenti software
"""
from fastapi import APIRouter, HTTPException, UploadFile, File, Depends, BackgroundTasks
from fastapi.responses import FileResponse
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
import os
import json
import subprocess
import hashlib
import aiofiles
import asyncio
from datetime import datetime
from pathlib import Path
import logging
import shutil
import requests

from api.auth import get_current_admin

router = APIRouter()
logger = logging.getLogger(__name__)

# Configurazione
UPDATE_CONFIG = {
    "update_server_url": os.getenv("UPDATE_SERVER_URL", "http://localhost:5000/api/v1"),
    "current_version": "0.2.0",  # Leggi da file VERSION
    "update_check_interval": 3600,  # 1 ora
    "temp_dir": "/tmp/armnas_updates",
    "backup_dir": "/opt/armnas/backups",
    "install_dir": "/opt/armnas",
    "max_backups": 5  # Numero massimo di backup da mantenere
}

# Leggi la versione corrente dal file VERSION
VERSION_FILE = Path(__file__).parent.parent.parent.parent / "VERSION"
if VERSION_FILE.exists():
    try:
        with open(VERSION_FILE, 'r') as f:
            UPDATE_CONFIG["current_version"] = f.read().strip()
    except Exception as e:
        logger.warning(f"Impossibile leggere il file VERSION: {e}")

# Crea directory temporanea se non esiste
Path(UPDATE_CONFIG["temp_dir"]).mkdir(parents=True, exist_ok=True)


def get_version():
    """Ottiene la versione corrente del sistema"""
    return UPDATE_CONFIG["current_version"]


def compare_versions(v1: str, v2: str) -> int:
    """
    Compara due versioni
    Returns: -1 se v1 < v2, 0 se v1 == v2, 1 se v1 > v2
    """
    try:
        parts1 = [int(x) for x in v1.split('.')]
        parts2 = [int(x) for x in v2.split('.')]
        
        # Padding per lunghezze diverse
        max_len = max(len(parts1), len(parts2))
        parts1.extend([0] * (max_len - len(parts1)))
        parts2.extend([0] * (max_len - len(parts2)))
        
        for p1, p2 in zip(parts1, parts2):
            if p1 < p2:
                return -1
            elif p1 > p2:
                return 1
        return 0
    except Exception as e:
        logger.error(f"Errore nel confronto versioni: {e}")
        return 0


def calculate_sha256(file_path: str) -> str:
    """Calcola il checksum SHA256 di un file"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


async def cleanup_old_backups():
    """Rimuove i backup più vecchi se si supera il limite"""
    try:
        backup_dir = Path(UPDATE_CONFIG["backup_dir"])
        if not backup_dir.exists():
            return
        
        # Lista tutti i backup
        backups = sorted(
            [f for f in backup_dir.glob("backup_*.tar.gz")],
            key=lambda x: x.stat().st_mtime,
            reverse=True
        )
        
        # Rimuovi quelli in eccesso
        for old_backup in backups[UPDATE_CONFIG["max_backups"]:]:
            try:
                old_backup.unlink()
                logger.info(f"Backup rimosso: {old_backup}")
            except Exception as e:
                logger.warning(f"Errore nella rimozione del backup {old_backup}: {e}")
    except Exception as e:
        logger.error(f"Errore nella pulizia dei backup: {e}")


@router.get("/status")
async def get_update_status(current_admin = Depends(get_current_admin)):
    """Restituisce lo stato corrente del sistema di aggiornamento"""
    return {
        "current_version": get_version(),
        "update_server_url": UPDATE_CONFIG["update_server_url"],
        "temp_dir": UPDATE_CONFIG["temp_dir"],
        "backup_dir": UPDATE_CONFIG["backup_dir"],
        "install_dir": UPDATE_CONFIG["install_dir"],
        "temp_dir_exists": os.path.exists(UPDATE_CONFIG["temp_dir"]),
        "backup_dir_exists": os.path.exists(UPDATE_CONFIG["backup_dir"]),
    }


@router.get("/check")
async def check_updates(current_admin = Depends(get_current_admin)):
    """Controlla se ci sono aggiornamenti disponibili"""
    try:
        current_version = get_version()
        
        # Costruisci URL per il controllo
        check_url = f"{UPDATE_CONFIG['update_server_url']}/check-update"
        params = {"current_version": current_version}
        
        # Effettua la richiesta al server
        response = requests.get(check_url, params=params, timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            
            # Se c'è un aggiornamento disponibile
            if data.get("update_available"):
                update_info = data.get("latest_version", {})
                return {
                    "update_available": True,
                    "current_version": current_version,
                    "latest_version": update_info.get("version"),
                    "download_url": update_info.get("download_url"),
                    "changelog": update_info.get("changelog"),
                    "critical": update_info.get("critical", False),
                    "size": update_info.get("size"),
                    "sha256": update_info.get("sha256"),
                    "release_date": update_info.get("created")
                }
            else:
                return {
                    "update_available": False,
                    "current_version": current_version,
                    "message": "Sistema aggiornato all'ultima versione"
                }
        elif response.status_code == 204:
            # Nessun aggiornamento disponibile
            return {
                "update_available": False,
                "current_version": current_version,
                "message": "Sistema aggiornato all'ultima versione"
            }
        else:
            raise HTTPException(
                status_code=response.status_code,
                detail=f"Errore dal server di aggiornamento: {response.text}"
            )
            
    except requests.exceptions.RequestException as e:
        logger.error(f"Errore nella connessione al server di aggiornamento: {e}")
        raise HTTPException(
            status_code=503,
            detail=f"Impossibile connettersi al server di aggiornamento: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Errore nel controllo aggiornamenti: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/download")
async def download_update(
    background_tasks: BackgroundTasks,
    download_url: str,
    filename: str,
    expected_sha256: Optional[str] = None,
    current_admin = Depends(get_current_admin)
):
    """Scarica un aggiornamento dal server"""
    try:
        temp_dir = Path(UPDATE_CONFIG["temp_dir"])
        temp_dir.mkdir(parents=True, exist_ok=True)
        
        file_path = temp_dir / filename
        
        # Scarica il file
        logger.info(f"Download aggiornamento da {download_url}")
        response = requests.get(download_url, stream=True, timeout=30)
        response.raise_for_status()
        
        # Salva il file
        with open(file_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        
        # Verifica checksum se fornito
        if expected_sha256:
            actual_sha256 = calculate_sha256(str(file_path))
            if actual_sha256 != expected_sha256:
                file_path.unlink()
                raise HTTPException(
                    status_code=400,
                    detail="Checksum non valido. Il file potrebbe essere corrotto."
                )
        
        # Rendi eseguibile
        os.chmod(file_path, 0o755)
        
        return {
            "success": True,
            "filename": filename,
            "path": str(file_path),
            "size": os.path.getsize(file_path),
            "sha256": calculate_sha256(str(file_path))
        }
        
    except Exception as e:
        logger.error(f"Errore nel download dell'aggiornamento: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/upload")
async def upload_update(
    file: UploadFile = File(...),
    current_admin = Depends(get_current_admin)
):
    """Upload manuale di un pacchetto di aggiornamento"""
    try:
        # Verifica estensione file
        if not file.filename.endswith('.run'):
            raise HTTPException(
                status_code=400,
                detail="Il file deve avere estensione .run"
            )
        
        temp_dir = Path(UPDATE_CONFIG["temp_dir"])
        temp_dir.mkdir(parents=True, exist_ok=True)
        
        file_path = temp_dir / file.filename
        
        # Salva il file
        async with aiofiles.open(file_path, 'wb') as f:
            content = await file.read()
            await f.write(content)
        
        # Rendi eseguibile
        os.chmod(file_path, 0o755)
        
        # Calcola checksum
        sha256 = calculate_sha256(str(file_path))
        
        return {
            "success": True,
            "filename": file.filename,
            "path": str(file_path),
            "size": os.path.getsize(file_path),
            "sha256": sha256
        }
        
    except Exception as e:
        logger.error(f"Errore nell'upload dell'aggiornamento: {e}")
        raise HTTPException(status_code=500, detail=str(e))


class InstallRequest(BaseModel):
    filename: str


@router.post("/install")
async def install_update(
    request: InstallRequest,
    background_tasks: BackgroundTasks,
    current_admin = Depends(get_current_admin)
):
    """Installa un aggiornamento"""
    try:
        file_path = Path(UPDATE_CONFIG["temp_dir"]) / request.filename
        
        if not file_path.exists():
            raise HTTPException(
                status_code=404,
                detail="File di aggiornamento non trovato"
            )
        
        if not file_path.is_file() or not os.access(file_path, os.X_OK):
            raise HTTPException(
                status_code=400,
                detail="Il file non è eseguibile"
            )
        
        # Pulizia backup vecchi in background
        background_tasks.add_task(cleanup_old_backups)
        
        # Avvia l'installazione in background
        logger.info(f"Avvio installazione aggiornamento: {request.filename}")
        
        # Esegui l'installazione in background
        async def run_installation():
            try:
                # Assicurati che il file sia eseguibile
                os.chmod(file_path, 0o755)
                
                # Esegui il file .run con --auto (nessuna conferma richiesta)
                process = await asyncio.create_subprocess_exec(
                    str(file_path),
                    "--auto",
                    stdout=asyncio.subprocess.PIPE,
                    stderr=asyncio.subprocess.PIPE,
                    cwd=UPDATE_CONFIG["temp_dir"]
                )
                
                stdout, stderr = await process.communicate()
                
                if process.returncode == 0:
                    logger.info(f"Installazione completata con successo: {request.filename}")
                    logger.info(f"Output: {stdout.decode()}")
                else:
                    logger.error(f"Installazione fallita: {request.filename}")
                    logger.error(f"Error: {stderr.decode()}")
                    
            except Exception as e:
                logger.error(f"Errore durante l'installazione in background: {e}")
        
        # Avvia in background
        background_tasks.add_task(run_installation)
        
        return {
            "success": True,
            "message": "Installazione avviata in background",
            "filename": request.filename,
            "note": "L'installazione è in corso. I servizi verranno riavviati automaticamente al termine (2-5 minuti). La connessione potrebbe interrompersi brevemente.",
            "warning": "Non chiudere questa pagina o il browser durante l'installazione."
        }
        
    except Exception as e:
        logger.error(f"Errore nell'installazione dell'aggiornamento: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/backups")
async def list_backups(current_admin = Depends(get_current_admin)):
    """Lista i backup disponibili"""
    try:
        backup_dir = Path(UPDATE_CONFIG["backup_dir"])
        
        if not backup_dir.exists():
            return {"backups": []}
        
        backups = []
        for backup_file in sorted(backup_dir.glob("backup_*.tar.gz"), key=lambda x: x.stat().st_mtime, reverse=True):
            stat = backup_file.stat()
            backups.append({
                "filename": backup_file.name,
                "path": str(backup_file),
                "size": stat.st_size,
                "created": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "size_mb": round(stat.st_size / (1024 * 1024), 2)
            })
        
        return {"backups": backups}
        
    except Exception as e:
        logger.error(f"Errore nel recupero dei backup: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/restore")
async def restore_backup(
    filename: str,
    current_admin = Depends(get_current_admin)
):
    """Ripristina un backup (richiede privilegi root)"""
    try:
        backup_path = Path(UPDATE_CONFIG["backup_dir"]) / filename
        
        if not backup_path.exists():
            raise HTTPException(
                status_code=404,
                detail="Backup non trovato"
            )
        
        # Il ripristino effettivo richiede privilegi root
        # Questo endpoint può solo preparare il comando
        
        return {
            "success": True,
            "message": "Ripristino preparato",
            "filename": filename,
            "command": f"sudo tar -xzf {backup_path} -C /opt",
            "note": "Eseguire il comando indicato con privilegi root per completare il ripristino"
        }
        
    except Exception as e:
        logger.error(f"Errore nel ripristino del backup: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/backups/{filename}")
async def delete_backup(
    filename: str,
    current_admin = Depends(get_current_admin)
):
    """Elimina un backup"""
    try:
        backup_path = Path(UPDATE_CONFIG["backup_dir"]) / filename
        
        if not backup_path.exists():
            raise HTTPException(
                status_code=404,
                detail="Backup non trovato"
            )
        
        # Verifica che sia un file backup valido
        if not filename.startswith("backup_") or not filename.endswith(".tar.gz"):
            raise HTTPException(
                status_code=400,
                detail="Nome file non valido"
            )
        
        backup_path.unlink()
        
        return {
            "success": True,
            "message": f"Backup {filename} eliminato"
        }
        
    except Exception as e:
        logger.error(f"Errore nell'eliminazione del backup: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/downloads")
async def list_downloaded_updates(current_admin = Depends(get_current_admin)):
    """Lista gli aggiornamenti scaricati ma non ancora installati"""
    try:
        temp_dir = Path(UPDATE_CONFIG["temp_dir"])
        
        if not temp_dir.exists():
            return {"updates": []}
        
        updates = []
        for update_file in sorted(temp_dir.glob("*.run"), key=lambda x: x.stat().st_mtime, reverse=True):
            stat = update_file.stat()
            updates.append({
                "filename": update_file.name,
                "path": str(update_file),
                "size": stat.st_size,
                "size_mb": round(stat.st_size / (1024 * 1024), 2),
                "downloaded": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "sha256": calculate_sha256(str(update_file))
            })
        
        return {"updates": updates}
        
    except Exception as e:
        logger.error(f"Errore nel recupero degli aggiornamenti scaricati: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/downloads/{filename}")
async def delete_downloaded_update(
    filename: str,
    current_admin = Depends(get_current_admin)
):
    """Elimina un aggiornamento scaricato"""
    try:
        file_path = Path(UPDATE_CONFIG["temp_dir"]) / filename
        
        if not file_path.exists():
            raise HTTPException(
                status_code=404,
                detail="File non trovato"
            )
        
        # Verifica che sia un file .run
        if not filename.endswith(".run"):
            raise HTTPException(
                status_code=400,
                detail="Nome file non valido"
            )
        
        file_path.unlink()
        
        return {
            "success": True,
            "message": f"File {filename} eliminato"
        }
        
    except Exception as e:
        logger.error(f"Errore nell'eliminazione del file: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/changelog/{version}")
async def get_changelog(
    version: str,
    current_admin = Depends(get_current_admin)
):
    """Ottiene il changelog per una specifica versione"""
    try:
        # Richiedi il changelog al server
        changelog_url = f"{UPDATE_CONFIG['update_server_url']}/changelog/{version}"
        response = requests.get(changelog_url, timeout=10)
        
        if response.status_code == 200:
            return response.json()
        else:
            raise HTTPException(
                status_code=response.status_code,
                detail="Changelog non disponibile"
            )
            
    except requests.exceptions.RequestException as e:
        logger.error(f"Errore nel recupero del changelog: {e}")
        raise HTTPException(
            status_code=503,
            detail=f"Impossibile recuperare il changelog: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Errore nel recupero del changelog: {e}")
        raise HTTPException(status_code=500, detail=str(e))

