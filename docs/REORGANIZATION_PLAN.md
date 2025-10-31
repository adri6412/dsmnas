# Piano di Riorganizzazione del Progetto

## Struttura Proposta

```
nas/
├── backend/              # Backend Python
│   ├── api/
│   │   ├── __init__.py
│   │   ├── auth/        # Autenticazione (modulo)
│   │   │   └── __init__.py
│   │   ├── routes/      # Route API
│   │   │   ├── auth.py  # Route autenticazione
│   │   │   ├── disk.py
│   │   │   ├── zfs.py
│   │   │   └── docker.py
│   │   ├── utils/       # Utility
│   │   ├── database.py
│   │   └── auth.py      # DA RIMUOVERE (duplicato)
│   ├── main.py
│   ├── requirements.txt
│   └── scripts/         # Script Python di utilità
│       ├── debug_users.py
│       └── fix_admin_user.py
│
├── frontend/            # Frontend Vue.js
│   ├── src/
│   └── ...
│
├── scripts/             # Script shell di sistema
│   ├── install.sh
│   ├── fix_*.sh
│   ├── compila_frontend.sh
│   └── live-build/      # Script per build ISO
│
├── docs/                # Documentazione
│   ├── README.md        # Documentazione principale
│   ├── DEPLOY_GUIDE.md
│   ├── VIRTUAL_DSM_SETUP.md
│   └── UPDATE_SYSTEM_README.md
│
├── config/              # File di configurazione
│   ├── docker-compose.yml
│   └── nginx-armnas.conf
│
└── server-update/       # Sistema di aggiornamento
    └── ...
```

## File da Rimuovere

- `backend/api/auth.py` (duplicato di `backend/api/auth/__init__.py`)
- `backend/api/routes/files.py` (non utilizzato)
- `backend/api/routes/network.py` (non utilizzato)
- `backend/api/routes/shares.py` (non utilizzato)
- `backend/api/routes/system.py` (non utilizzato)
- `backend/api/routes/service.py` (non utilizzato)
- `backend/api/routes/test.py` (non utilizzato)
- `backend/api/routes/updates.py` (non utilizzato)
- `backend/api/routes/user_system.py` (non utilizzato)
- `backend/api/routes/users.py` (non utilizzato)
- `frontend/src/locales/it.json.new` (file temporaneo)
- `frontend/src/debug_auth.js` (file debug)

## File da Spostare

- Script nella root → `scripts/`
- Documentazione → `docs/`
- Configurazioni → `config/`
- Script Python di debug → `backend/scripts/`

