from fastapi import APIRouter, Depends, HTTPException, status, Response, Request
from fastapi.security import APIKeyCookie
from sqlalchemy.orm import Session
from pydantic import BaseModel
from typing import Optional
from datetime import timedelta

from ..database import get_db, User
from ..auth import (
    authenticate_user, 
    create_session_token, 
    get_current_user, 
    get_current_admin,
    get_password_hash,
    verify_password,
    active_sessions
)

router = APIRouter()

# Modelli Pydantic
class UserLogin(BaseModel):
    username: str
    password: str
    remember_me: bool = False

class UserCreate(BaseModel):
    username: str
    password: str
    is_admin: bool = False

class UserResponse(BaseModel):
    username: str
    is_admin: bool

class MessageResponse(BaseModel):
    message: str
    
class ChangePasswordRequest(BaseModel):
    current_password: str
    new_password: str

# Endpoint per il login
@router.post("/login", response_model=UserResponse)
async def login(user_data: UserLogin, response: Response, db: Session = Depends(get_db)):
    user = authenticate_user(db, user_data.username, user_data.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Username o password non corretti",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # Imposta la durata della sessione
    expires_delta = timedelta(days=30) if user_data.remember_me else timedelta(hours=1)
    
    # Crea il token di sessione
    token = create_session_token(user.username, expires_delta)
    
    # Imposta il cookie di sessione
    cookie_max_age = 30 * 24 * 60 * 60 if user_data.remember_me else 60 * 60
    response.set_cookie(
        key="session_token",
        value=token,
        max_age=cookie_max_age,
        httponly=True,
        samesite="lax",
        secure=False  # Impostare a True in produzione con HTTPS
    )
    
    return UserResponse(username=user.username, is_admin=user.is_admin)

# Endpoint per il logout
@router.post("/logout", response_model=MessageResponse)
async def logout(response: Response, token: str = Depends(APIKeyCookie(name="session_token"))):
    # Rimuovi il token dalla lista delle sessioni attive
    if token in active_sessions:
        del active_sessions[token]
    
    # Rimuovi il cookie
    response.delete_cookie(key="session_token")
    return {"message": "Logout effettuato con successo"}

# Endpoint per il logout da tutte le sessioni
@router.post("/logout-all", response_model=MessageResponse)
async def logout_all(
    response: Response, 
    current_user: User = Depends(get_current_user)
):
    # Rimuovi tutte le sessioni dell'utente corrente
    username = current_user.username
    tokens_to_remove = [
        token for token, (user, _) in active_sessions.items() 
        if user == username
    ]
    
    for token in tokens_to_remove:
        del active_sessions[token]
    
    # Rimuovi il cookie corrente
    response.delete_cookie(key="session_token")
    
    return {"message": "Logout effettuato da tutte le sessioni"}

# Endpoint per il cambio password
@router.post("/change-password", response_model=MessageResponse)
async def change_password(
    password_data: ChangePasswordRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    # Verifica la password corrente
    if not verify_password(password_data.current_password, current_user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password attuale non corretta"
        )
    
    # Aggiorna la password
    current_user.password_hash = get_password_hash(password_data.new_password)
    db.commit()
    
    return {"message": "Password aggiornata con successo"}

# Endpoint per ottenere l'utente corrente
@router.get("/me", response_model=UserResponse)
async def read_users_me(current_user: User = Depends(get_current_user)):
    return UserResponse(username=current_user.username, is_admin=current_user.is_admin)

# Endpoint per creare un nuovo utente (solo admin)
@router.post("/users", response_model=UserResponse)
async def create_user(
    user_data: UserCreate, 
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    # Verifica se l'utente esiste già
    db_user = db.query(User).filter(User.username == user_data.username).first()
    if db_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username già registrato"
        )
    
    # Crea il nuovo utente
    new_user = User(
        username=user_data.username,
        password_hash=get_password_hash(user_data.password),
        is_admin=user_data.is_admin
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return UserResponse(username=new_user.username, is_admin=new_user.is_admin)

# Endpoint per elencare tutti gli utenti (solo admin)
@router.get("/users", response_model=list[UserResponse])
async def list_users(
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    users = db.query(User).all()
    return [UserResponse(username=user.username, is_admin=user.is_admin) for user in users]

# Endpoint per eliminare un utente (solo admin)
@router.delete("/users/{username}", response_model=MessageResponse)
async def delete_user(
    username: str,
    current_user: User = Depends(get_current_admin),
    db: Session = Depends(get_db)
):
    # Non permettere di eliminare l'utente admin
    if username == "admin":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Non è possibile eliminare l'utente admin"
        )
    
    # Non permettere di eliminare se stessi
    if username == current_user.username:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Non è possibile eliminare il proprio account"
        )
    
    # Trova l'utente
    user = db.query(User).filter(User.username == username).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Utente non trovato"
        )
    
    # Elimina l'utente
    db.delete(user)
    db.commit()
    
    return {"message": f"Utente {username} eliminato con successo"}