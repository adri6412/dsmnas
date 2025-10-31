# Struttura del Progetto ArmNAS

Questo documento descrive la struttura organizzata del progetto ArmNAS.

## 📂 Struttura Directory

```
nas/
├── backend/              # Backend Python (FastAPI)
│   ├── api/
│   │   ├── __init__.py
│   │   ├── auth/        # Modulo autenticazione
│   │   │   └── __init__.py
│   │   ├── routes/      # Route API
│   │   │   ├── auth.py  # Route autenticazione
│   │   │   ├── disk.py  # Route gestione dischi
│   │   │   ├── zfs.py   # Route gestione ZFS
│   │   │   └── docker.py # Route Virtual DSM
│   │   ├── utils/       # Utility functions
│   │   │   ├── docker_utils.py
│   │   │   └── zfs_utils.py
│   │   └── database.py  # Configurazione database SQLite
│   ├── scripts/         # Script Python di utilità
│   │   ├── fix_admin_user.py
│   │   └── debug_users.py
│   ├── main.py          # Entry point FastAPI
│   └── requirements.txt # Dipendenze Python
│
├── frontend/            # Frontend Vue.js
│   ├── src/
│   │   ├── components/  # Componenti Vue riutilizzabili
│   │   │   └── layout/  # Componenti layout (Navbar, Sidebar)
│   │   ├── views/       # Viste/Page component
│   │   │   ├── Login.vue
│   │   │   ├── Dashboard.vue
│   │   │   ├── DiskManagement.vue
│   │   │   ├── ZFSManagement.vue
│   │   │   ├── VirtualDSM.vue
│   │   │   ├── AuthUserManagement.vue
│   │   │   └── UserProfile.vue
│   │   ├── router/      # Configurazione routing Vue Router
│   │   ├── store/       # Vuex store
│   │   │   └── modules/ # Moduli store (auth, disk)
│   │   ├── plugins/     # Plugin Vue (axios)
│   │   ├── locales/     # File di traduzione i18n
│   │   └── main.js      # Entry point Vue
│   ├── dist/           # Build di produzione
│   ├── package.json
│   └── vite.config.js  # Configurazione Vite
│
├── scripts/             # Script shell di sistema
│   ├── install.sh      # Script di installazione principale
│   ├── fix_backend.sh  # Script correzione backend
│   ├── fix_nginx.sh    # Script correzione Nginx
│   ├── fix_permissions.sh # Script correzione permessi
│   ├── installer_dsm.sh # Installer Virtual DSM (makeself)
│   ├── launch.sh       # Script di avvio rapido
│   ├── compila_frontend.sh # Script build frontend
│   └── create_package_manual.py # Script creazione package
│
├── config/              # File di configurazione
│   ├── docker-compose.yml  # Configurazione Virtual DSM container
│   └── nginx-armnas.conf   # Configurazione Nginx (riferimento)
│
├── live-build/          # Script per build ISO Debian Live
│   ├── build.sh        # Script principale build ISO
│   ├── auto-install-dsm.sh # Script installazione automatica DSM
│   ├── bootstrap.sh    # Script bootstrap ambiente
│   ├── config.sh       # Script configurazione live-build
│   └── README.md       # Documentazione build ISO
│
├── server-update/       # Sistema di aggiornamento
│   ├── build_and_release.sh # Script build release
│   ├── create_update_package_fixed.py # Script creazione update
│   ├── deploy_update_system.sh # Script deploy aggiornamenti
│   ├── manage_updates.sh # Script gestione aggiornamenti
│   ├── install_makeself.sh # Installer makeself
│   ├── update_server_example.py # Server aggiornamenti esempio
│   └── updates/        # Directory pacchetti aggiornamento
│
└── docs/               # Documentazione
    ├── README.md       # Documentazione principale
    ├── STRUCTURE.md    # Questo file
    ├── DEPLOY_GUIDE.md # Guida deployment
    ├── VIRTUAL_DSM_SETUP.md # Setup Virtual DSM
    └── UPDATE_SYSTEM_README.md # Sistema aggiornamenti
```

## 📝 File Principali

### Backend

- **`backend/main.py`**: Entry point FastAPI, configura middleware e router
- **`backend/api/auth/__init__.py`**: Logica autenticazione con Argon2
- **`backend/api/routes/`**: Route API REST
- **`backend/api/utils/`**: Funzioni utility per Docker e ZFS

### Frontend

- **`frontend/src/main.js`**: Entry point Vue app
- **`frontend/src/router/index.js`**: Configurazione routing
- **`frontend/src/store/index.js`**: Configurazione Vuex store
- **`frontend/src/views/`**: Componenti pagina principali

### Script

- **`scripts/install.sh`**: Script principale installazione sistema completo
- **`scripts/installer_dsm.sh`**: Installer Virtual DSM (makeself)
- **`live-build/build.sh`**: Script build ISO Debian Live

## 🔄 Convenzioni

1. **Script shell**: Tutti gli script di sistema sono in `scripts/`
2. **Configurazioni**: File di configurazione in `config/`
3. **Documentazione**: Tutta la documentazione in `docs/`
4. **Script Python di utilità**: In `backend/scripts/`
5. **Route API**: Una route per file in `backend/api/routes/`

## 🚀 Workflow

### Sviluppo
1. Modifiche backend → `backend/`
2. Modifiche frontend → `frontend/src/`
3. Script di sistema → `scripts/`

### Build
1. Frontend: `cd frontend && npm run build`
2. ISO: `cd live-build && sudo ./build.sh`

### Installazione
1. `cd scripts && sudo ./install.sh`

