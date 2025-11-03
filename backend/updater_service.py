"""
Servizio separato per la gestione degli aggiornamenti
Gira su porta 8001 e rimane attivo durante gli update del backend principale
"""
from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import uvicorn
import os
import subprocess
import hashlib
import aiofiles
from pathlib import Path
from datetime import datetime
from typing import Optional
import logging

# Configurazione logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="ArmNAS Update Service",
    description="Servizio separato per gestione aggiornamenti",
    version="1.0.0"
)

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configurazione
UPDATE_DIR = Path("/tmp/armnas_updates")
BACKUP_DIR = Path("/opt/armnas/backups")
INSTALL_DIR = Path("/opt/armnas")
VERSION_FILE = Path("/opt/armnas/VERSION")

UPDATE_DIR.mkdir(parents=True, exist_ok=True)
BACKUP_DIR.mkdir(parents=True, exist_ok=True)


class UploadResponse(BaseModel):
    success: bool
    filename: str
    size: int
    sha256: str


class InstallRequest(BaseModel):
    filename: str


def get_version():
    """Legge la versione corrente"""
    if VERSION_FILE.exists():
        try:
            return VERSION_FILE.read_text().strip()
        except:
            pass
    return "0.2.0"


def calculate_sha256(file_path: Path) -> str:
    """Calcola SHA256 di un file"""
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()


@app.get("/")
async def root():
    """Root endpoint"""
    return {
        "service": "ArmNAS Update Service",
        "version": "1.0.0",
        "status": "online"
    }


@app.get("/status")
async def get_status():
    """Stato del servizio"""
    return {
        "service": "updater",
        "current_version": get_version(),
        "update_dir": str(UPDATE_DIR),
        "backup_dir": str(BACKUP_DIR),
        "install_dir": str(INSTALL_DIR)
    }


@app.post("/upload")
async def upload_update(file: UploadFile = File(...)):
    """Upload pacchetto di aggiornamento"""
    try:
        if not file.filename.endswith('.run'):
            raise HTTPException(status_code=400, detail="Solo file .run sono accettati")
        
        file_path = UPDATE_DIR / file.filename
        
        # Salva il file
        async with aiofiles.open(file_path, 'wb') as f:
            content = await file.read()
            await f.write(content)
        
        # Rendi eseguibile
        os.chmod(file_path, 0o755)
        
        # Calcola checksum
        sha256 = calculate_sha256(file_path)
        
        logger.info(f"✅ File caricato: {file.filename} ({file_path.stat().st_size} bytes)")
        
        return {
            "success": True,
            "filename": file.filename,
            "size": file_path.stat().st_size,
            "sha256": sha256
        }
        
    except Exception as e:
        logger.error(f"Errore upload: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/downloads")
async def list_downloads():
    """Lista aggiornamenti scaricati"""
    try:
        updates = []
        for file_path in sorted(UPDATE_DIR.glob("*.run"), key=lambda x: x.stat().st_mtime, reverse=True):
            stat = file_path.stat()
            updates.append({
                "filename": file_path.name,
                "size": stat.st_size,
                "size_mb": round(stat.st_size / (1024 * 1024), 2),
                "downloaded": datetime.fromtimestamp(stat.st_mtime).isoformat(),
                "sha256": calculate_sha256(file_path)
            })
        
        return {"updates": updates}
    except Exception as e:
        logger.error(f"Errore lista downloads: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/downloads/{filename}")
async def delete_download(filename: str):
    """Elimina aggiornamento scaricato"""
    try:
        if not filename.endswith(".run"):
            raise HTTPException(status_code=400, detail="Nome file non valido")
        
        file_path = UPDATE_DIR / filename
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="File non trovato")
        
        file_path.unlink()
        logger.info(f"✅ File eliminato: {filename}")
        
        return {"success": True, "message": f"File {filename} eliminato"}
    except Exception as e:
        logger.error(f"Errore eliminazione: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/install")
async def install_update(request: InstallRequest):
    """Avvia installazione aggiornamento"""
    try:
        file_path = UPDATE_DIR / request.filename
        
        if not file_path.exists():
            raise HTTPException(status_code=404, detail="File non trovato")
        
        if not file_path.is_file() or not os.access(file_path, os.X_OK):
            raise HTTPException(status_code=400, detail="File non eseguibile")
        
        # Log file per l'installazione
        log_file = UPDATE_DIR / f"install_{request.filename}.log"
        
        # Lancia il .run in background con nohup
        command = f"nohup {file_path} --auto > {log_file} 2>&1 &"
        subprocess.Popen(
            command,
            shell=True,
            cwd=str(UPDATE_DIR),
            start_new_session=True
        )
        
        logger.info(f"✅ Installazione lanciata: {request.filename}")
        logger.info(f"📋 Log: {log_file}")
        
        return {
            "success": True,
            "message": "Installazione avviata in background",
            "filename": request.filename,
            "log_file": str(log_file)
        }
        
    except Exception as e:
        logger.error(f"Errore installazione: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/backups")
async def list_backups():
    """Lista backup disponibili"""
    try:
        backups = []
        for backup_file in sorted(BACKUP_DIR.glob("backup_*.tar.gz"), key=lambda x: x.stat().st_mtime, reverse=True):
            stat = backup_file.stat()
            backups.append({
                "filename": backup_file.name,
                "size": stat.st_size,
                "size_mb": round(stat.st_size / (1024 * 1024), 2),
                "created": datetime.fromtimestamp(stat.st_mtime).isoformat()
            })
        
        return {"backups": backups}
    except Exception as e:
        logger.error(f"Errore lista backups: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/backups/{filename}")
async def delete_backup(filename: str):
    """Elimina un backup"""
    try:
        if not filename.startswith("backup_") or not filename.endswith(".tar.gz"):
            raise HTTPException(status_code=400, detail="Nome file non valido")
        
        backup_path = BACKUP_DIR / filename
        if not backup_path.exists():
            raise HTTPException(status_code=404, detail="Backup non trovato")
        
        backup_path.unlink()
        logger.info(f"✅ Backup eliminato: {filename}")
        
        return {"success": True, "message": f"Backup {filename} eliminato"}
    except Exception as e:
        logger.error(f"Errore eliminazione backup: {e}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    logger.info("🚀 Avvio ArmNAS Update Service su porta 8001")
    uvicorn.run(app, host="0.0.0.0", port=8001)

