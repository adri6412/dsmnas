# ArmNAS - Sistema di Gestione ZFS e Virtual DSM

Sistema completo per la gestione di pool ZFS, dischi e Virtual DSM su Debian.

## 📁 Struttura del Progetto

```
nas/
├── backend/              # Backend Python (FastAPI)
│   ├── api/
│   │   ├── auth/        # Autenticazione (Argon2)
│   │   ├── routes/      # Route API (auth, disk, zfs, docker)
│   │   ├── utils/       # Utility (docker, zfs)
│   │   └── database.py
│   ├── scripts/         # Script Python di utilità
│   ├── main.py
│   └── requirements.txt
│
├── frontend/            # Frontend Vue.js
│   ├── src/
│   │   ├── components/  # Componenti Vue
│   │   ├── views/       # Viste (Dashboard, ZFS, VirtualDSM, etc.)
│   │   ├── router/      # Routing
│   │   ├── store/       # Vuex store
│   │   └── locales/     # Traduzioni
│   └── dist/           # Build frontend
│
├── scripts/             # Script shell di sistema
│   ├── install.sh      # Script di installazione principale
│   ├── fix_*.sh        # Script di correzione
│   ├── installer_dsm.sh # Installer Virtual DSM
│   └── compila_frontend.sh
│
├── config/              # File di configurazione
│   ├── docker-compose.yml  # Configurazione Virtual DSM
│   └── nginx-armnas.conf   # Configurazione Nginx
│
├── live-build/          # Script per build ISO Debian Live
│   ├── build.sh
│   ├── auto-install-dsm.sh
│   └── ...
│
├── server-update/       # Sistema di aggiornamento
│   └── ...
│
└── docs/               # Documentazione
    ├── README.md        # Questa documentazione
    ├── DEPLOY_GUIDE.md
    ├── VIRTUAL_DSM_SETUP.md
    └── UPDATE_SYSTEM_README.md
```

## 🚀 Quick Start

### Installazione

```bash
cd scripts
chmod +x install.sh
sudo ./install.sh
```

L'installazione configura automaticamente:
- Backend FastAPI su porta 8000
- Frontend Vue.js servito da Nginx
- OverlayFS per proteggere la SD card
- Bind mount per `/opt/armnas` (persistente)

### Primo Avvio

1. Accedi all'interfaccia web: `http://<IP_SERVER>`
2. Credenziali predefinite:
   - Username: `admin`
   - Password: `admin` (cambiala dopo il primo accesso!)

## 🔧 Funzionalità Principali

### Gestione Dischi
- Visualizzazione dischi disponibili
- Formattazione e preparazione dischi

### Gestione ZFS
- Creazione pool ZFS (RAIDZ, RAIDZ2, RAIDZ3, Mirror, Stripe)
- Pool montato automaticamente su `/storage`
- Configurazione automatica Docker su `/storage/docker`

### Virtual DSM
- Installazione e configurazione Virtual DSM
- Gestione spazio disco
- Configurazione Serial Number e MAC Address

### Autenticazione
- Sistema di autenticazione con Argon2 (senza limite password)
- Gestione utenti amministratori

## 📝 Configurazione

### Docker Data Root

Quando crei un pool ZFS montato su `/storage`, Docker viene automaticamente configurato per usare `/storage/docker` come data-root.

### OverlayFS

Il sistema è configurato con OverlayFS per proteggere la SD card:
- Scritture temporanee su RAM
- `/opt/armnas` escluso dall'overlay (persistente su SD)
- `/storage` su ZFS (persistente su pool)

## 🛠️ Sviluppo

### Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

### Frontend

```bash
cd frontend
npm install
npm run dev
```

### Build ISO

```bash
cd live-build
sudo ./build.sh
```

## 📚 Documentazione

Consulta la documentazione completa in `docs/`:
- `DEPLOY_GUIDE.md` - Guida al deployment
- `VIRTUAL_DSM_SETUP.md` - Setup Virtual DSM
- `UPDATE_SYSTEM_README.md` - Sistema di aggiornamento

## 🔒 Sicurezza

- Autenticazione Argon2 (senza limiti password)
- Cookie di sessione sicuri
- Protezione endpoint API
- OverlayFS per ridurre scritture su SD

## 📄 Licenza

[Inserisci la licenza qui]

## 🤝 Contribuire

[Istruzioni per contribuire]

