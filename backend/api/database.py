from sqlalchemy import create_engine, Column, Integer, String, Boolean
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os

# Crea la directory per il database se non esiste
data_dir = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "data")
os.makedirs(data_dir, exist_ok=True)

# Crea il motore del database SQLite
SQLALCHEMY_DATABASE_URL = f"sqlite:///{os.path.join(data_dir, 'armnas.db')}"
engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args={"check_same_thread": False})

# Crea la sessione
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# Crea la base per i modelli
Base = declarative_base()

# Modello per gli utenti dell'applicazione
class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password_hash = Column(String)
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)

# Crea le tabelle nel database
Base.metadata.create_all(bind=engine)

# Funzione per ottenere una sessione del database
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()