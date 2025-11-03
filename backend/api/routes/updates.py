from fastapi import APIRouter, Depends, HTTPException, UploadFile, File
from sqlalchemy.orm import Session
from api.database import get_db
from api.auth import get_current_admin
from api.models import User
import os
import shutil
from datetime import datetime
from pathlib import Path

router = APIRouter()

# Directory per gli aggiornamenti pending
PENDING_UPDATES_DIR = "/opt/armnas/pending-updates"
UPDATE_HISTORY_FILE = "/opt/armnas/pending-updates/update-history.log"

# Assicurati che la directory esista
os.makedirs(PENDING_UPDATES_DIR, exist_ok=True)


@router.post("/upload")
async def upload_update(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_admin)
):
    """
    Carica un file di aggiornamento .run nella directory pending-updates
    """
    
    # Verifica che sia un file .run
    if not file.filename.endswith('.run'):
        raise HTTPException(status_code=400, detail="Solo file .run sono accettati")
    
    # Verifica dimensione file (max 500MB)
    file.file.seek(0, 2)  # Vai alla fine del file
    file_size = file.file.tell()
    file.file.seek(0)  # Torna all'inizio
    
    if file_size > 500 * 1024 * 1024:  # 500MB
        raise HTTPException(status_code=400, detail="File troppo grande (max 500MB)")
    
    # Salva il file
    file_path = os.path.join(PENDING_UPDATES_DIR, file.filename)
    
    # Se il file esiste già, sovras crivilo
    try:
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
        
        # Imposta permessi eseguibili
        os.chmod(file_path, 0o755)
        
        return {
            "success": True,
            "message": f"Aggiornamento {file.filename} caricato con successo",
            "filename": file.filename,
            "size": file_size
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nel salvataggio del file: {str(e)}")


@router.get("/pending")
async def get_pending_updates(
    current_user: User = Depends(get_current_admin)
):
    """
    Ottiene la lista degli aggiornamenti in attesa
    """
    
    try:
        updates = []
        
        if os.path.exists(PENDING_UPDATES_DIR):
            for filename in os.listdir(PENDING_UPDATES_DIR):
                if filename.endswith('.run'):
                    file_path = os.path.join(PENDING_UPDATES_DIR, filename)
                    stat = os.stat(file_path)
                    
                    updates.append({
                        "filename": filename,
                        "size": stat.st_size,
                        "uploaded_at": datetime.fromtimestamp(stat.st_mtime).isoformat()
                    })
        
        # Ordina per data (più recente prima)
        updates.sort(key=lambda x: x['uploaded_at'], reverse=True)
        
        return {"updates": updates}
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nel recupero degli aggiornamenti: {str(e)}")


@router.delete("/pending/{filename}")
async def delete_pending_update(
    filename: str,
    current_user: User = Depends(get_current_admin)
):
    """
    Elimina un aggiornamento pending
    """
    
    # Verifica che il filename non contenga path traversal
    if '/' in filename or '..' in filename:
        raise HTTPException(status_code=400, detail="Nome file non valido")
    
    # Verifica che sia un file .run
    if not filename.endswith('.run'):
        raise HTTPException(status_code=400, detail="Solo file .run possono essere eliminati")
    
    file_path = os.path.join(PENDING_UPDATES_DIR, filename)
    
    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="File non trovato")
    
    try:
        os.remove(file_path)
        return {
            "success": True,
            "message": f"Aggiornamento {filename} eliminato"
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nell'eliminazione: {str(e)}")


@router.get("/history")
async def get_update_history(
    current_user: User = Depends(get_current_admin)
):
    """
    Ottiene la cronologia degli aggiornamenti installati
    """
    
    history = []
    
    try:
        if os.path.exists(UPDATE_HISTORY_FILE):
            with open(UPDATE_HISTORY_FILE, 'r') as f:
                lines = f.readlines()
                
                # Limita alle ultime 20 voci
                for line in lines[-20:]:
                    parts = line.strip().split('|')
                    if len(parts) >= 3:
                        history.append({
                            "date": parts[0],
                            "filename": parts[1],
                            "status": parts[2],
                            "error_code": parts[3] if len(parts) > 3 else None
                        })
        
        # Inverti per mostrare il più recente prima
        history.reverse()
        
        return {"history": history}
    
    except Exception as e:
        print(f"Errore nel leggere la cronologia: {e}")
        return {"history": []}
