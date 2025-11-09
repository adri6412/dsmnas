from fastapi import FastAPI, Depends, HTTPException, status, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
import uvicorn
import os
from sqlalchemy.orm import Session

from api.routes import disk, auth, zfs, docker, system, updates, vdsm_network
from api.database import get_db
from api.auth import get_current_admin, init_admin_user

app = FastAPI(
    title="ZFS Disk Management API",
    description="API per la gestione di dischi, ZFS e Virtual DSM",
    version="0.2.1"
)

# Configurazione CORS per consentire le richieste dal frontend
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In produzione, limitare agli host consentiti
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Middleware per verificare l'autenticazione per tutte le API tranne /api/auth/login
@app.middleware("http")
async def auth_middleware(request: Request, call_next):
    # Escludi le rotte di autenticazione e la documentazione
    excluded_paths = ["/api/auth/login", "/docs", "/redoc", "/openapi.json"]
    
    if any(request.url.path.startswith(path) for path in excluded_paths):
        return await call_next(request)
    
    # Verifica il cookie di sessione
    session_token = request.cookies.get("session_token")
    
    # Se non c'è un token di sessione, continua comunque (la protezione avverrà a livello di endpoint)
    if not session_token:
        return await call_next(request)
    
    # Continua con la richiesta
    return await call_next(request)

# Inclusione dei router per le diverse funzionalità
app.include_router(auth.router, prefix="/api/auth", tags=["Autenticazione"])
app.include_router(disk.router, prefix="/api/disk", tags=["Disco"], dependencies=[Depends(get_current_admin)])
app.include_router(zfs.router, prefix="/api/zfs", tags=["ZFS"], dependencies=[Depends(get_current_admin)])
app.include_router(docker.router, prefix="/api/docker", tags=["Virtual DSM"], dependencies=[Depends(get_current_admin)])
app.include_router(vdsm_network.router, prefix="/api/vdsm", tags=["Virtual DSM Network"], dependencies=[Depends(get_current_admin)])
app.include_router(system.router, prefix="/api/system", tags=["Sistema"], dependencies=[Depends(get_current_admin)])
app.include_router(updates.router, prefix="/api/updates", tags=["Aggiornamenti"], dependencies=[Depends(get_current_admin)])

# Commentiamo questa parte perché i file statici sono serviti da Nginx
# app.mount("/", StaticFiles(directory="../frontend/dist", html=True), name="frontend")

# Inizializza l'utente admin all'avvio dell'applicazione
@app.on_event("startup")
async def startup_event():
    db = next(get_db())
    init_admin_user(db)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)