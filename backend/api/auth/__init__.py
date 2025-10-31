from fastapi import Depends, HTTPException, status
from fastapi.security import APIKeyCookie
from sqlalchemy.orm import Session
from passlib.context import CryptContext
from typing import Optional
from datetime import datetime, timedelta
import secrets
import os

from ..database import get_db, User

# Configurazione della sicurezza
# Usiamo Argon2 invece di bcrypt perché non ha il limite di 72 byte
pwd_context = CryptContext(schemes=["argon2"], deprecated="auto")
cookie_sec = APIKeyCookie(name="session_token")

# Dizionario per memorizzare le sessioni attive
# Chiave: token, Valore: (username, scadenza)
active_sessions = {}

# Funzione per verificare la password
def verify_password(plain_password, hashed_password):
    # Con Argon2 non c'è limite di lunghezza per le password
    return pwd_context.verify(plain_password, hashed_password)

# Funzione per generare l'hash della password
def get_password_hash(password):
    # Con Argon2 non c'è limite di lunghezza per le password (a differenza di bcrypt che ha 72 byte)
    return pwd_context.hash(password)

# Funzione per autenticare un utente
def authenticate_user(db: Session, username: str, password: str):
    user = db.query(User).filter(User.username == username).first()
    if not user:
        return False
    if not verify_password(password, user.password_hash):
        return False
    return user

# Funzione per creare un token di sessione
def create_session_token(username: str, expires_delta: Optional[timedelta] = None):
    token = secrets.token_hex(32)
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=60)
    
    active_sessions[token] = (username, expire)
    return token

# Funzione per ottenere l'utente corrente
def get_current_user(token: str = Depends(cookie_sec), db: Session = Depends(get_db)):
    if token not in active_sessions:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sessione non valida o scaduta",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    username, expire = active_sessions[token]
    if datetime.utcnow() > expire:
        del active_sessions[token]
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Sessione scaduta",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    user = db.query(User).filter(User.username == username).first()
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utente non trovato",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Utente disattivato",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    return user

# Funzione per ottenere l'utente amministratore corrente
def get_current_admin(current_user: User = Depends(get_current_user)):
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Permessi insufficienti",
        )
    return current_user

# Funzione per inizializzare l'utente admin se non esiste
def init_admin_user(db: Session):
    admin = db.query(User).filter(User.username == "admin").first()
    if not admin:
        admin_password = os.environ.get("ADMIN_PASSWORD", "admin")
        admin = User(
            username="admin",
            password_hash=get_password_hash(admin_password),
            is_active=True,
            is_admin=True
        )
        db.add(admin)
        db.commit()
        print("Utente admin creato con successo!")
    return admin