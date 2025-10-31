# Sistema di Aggiornamento ArmNAS

Questo documento descrive il sistema di aggiornamento automatico implementato per ArmNAS, che permette di aggiornare il sistema completo tramite interfaccia web e pacchetti autoinstallanti.

## 🚀 Caratteristiche

- **Aggiornamenti automatici** da server remoto
- **Pacchetti autoinstallanti** (.run) con tutto incluso
- **Interfaccia web** per gestire gli aggiornamenti
- **Sistema di backup** automatico prima degli aggiornamenti
- **Verifica integrità** con checksum SHA256
- **Rollback** in caso di problemi
- **Upload manuale** di pacchetti di aggiornamento

## 📁 Struttura File

```
nas/
├── backend/api/routes/updates.py          # API per aggiornamenti
├── frontend/src/views/UpdateManagement.vue # Interfaccia web
├── create_update_package.py               # Script per creare pacchetti
├── update_server_example.py               # Server di distribuzione
├── manage_updates.sh                      # Script di utilità
└── UPDATE_SYSTEM_README.md               # Questa documentazione
```

## 🔧 Configurazione

### 1. Backend

Il sistema è già integrato nel backend FastAPI. Le API sono disponibili su:

- `GET /api/updates/check` - Controlla aggiornamenti
- `GET /api/updates/status` - Stato del sistema
- `POST /api/updates/download` - Scarica aggiornamento
- `POST /api/updates/install` - Installa aggiornamento
- `POST /api/updates/upload` - Upload manuale
- `GET /api/updates/backups` - Lista backup
- `POST /api/updates/restore` - Ripristina backup

### 2. Frontend

La pagina di gestione aggiornamenti è accessibile dal menu "Aggiornamenti" (solo per amministratori).

### 3. Configurazione Server Aggiornamenti

Modifica il file `backend/api/routes/updates.py` per configurare il server:

```python
UPDATE_CONFIG = {
    "update_server_url": "https://your-update-server.com/api/v1",
    "current_version": "0.1.0",
    "update_check_interval": 3600,
    "temp_dir": "/tmp/armnas_updates",
    "backup_dir": "/opt/armnas/backups",
    "install_dir": "/opt/armnas"
}
```

## 📦 Creazione Pacchetti di Aggiornamento

### Metodo 1: Script Python

```bash
# Crea un pacchetto base
python3 create_update_package.py 1.2.3

# Con changelog e marcato come critico
python3 create_update_package.py 1.2.3 \
  --changelog "Nuove funzionalità" "Correzioni bug" "Miglioramenti sicurezza" \
  --critical

# Da directory specifica
python3 create_update_package.py 1.2.3 --source /path/to/source --output ./releases
```

### Metodo 2: Script di Gestione

```bash
# Crea pacchetto
./manage_updates.sh create 1.2.3 --changelog "Fix critici,Nuove funzioni" --critical

# Lista pacchetti disponibili
./manage_updates.sh list

# Testa un pacchetto
./manage_updates.sh test updates/armnas_update_v1.2.3.run

# Avvia server di distribuzione
./manage_updates.sh server
```

## 🌐 Server di Distribuzione

### Avvio Server di Esempio

```bash
# Installa dipendenze
pip3 install flask

# Avvia server
python3 update_server_example.py
```

Il server sarà disponibile su `http://localhost:5000` con le seguenti API:

- `GET /api/v1/check-update?current_version=X.X.X`
- `GET /api/v1/versions`
- `GET /api/v1/download/<filename>`
- `POST /api/v1/upload` (richiede autenticazione)

### Configurazione Produzione

Per un ambiente di produzione:

1. **Usa un server web robusto** (nginx + gunicorn)
2. **Implementa autenticazione** per upload
3. **Configura HTTPS**
4. **Usa un database** invece del dizionario in memoria
5. **Implementa logging** e monitoraggio

## 🔄 Processo di Aggiornamento

### Automatico (da Interfaccia Web)

1. L'utente accede alla pagina "Aggiornamenti"
2. Il sistema controlla automaticamente gli aggiornamenti disponibili
3. Se disponibile, mostra le informazioni dell'aggiornamento
4. L'utente clicca "Scarica e Installa"
5. Il sistema:
   - Scarica il pacchetto
   - Verifica l'integrità (checksum)
   - Crea un backup del sistema corrente
   - Installa l'aggiornamento
   - Riavvia i servizi

### Manuale (Upload)

1. L'amministratore carica un file `.run`
2. Il sistema salva il file nella directory temporanea
3. L'amministratore può installarlo dalla lista dei file caricati

### Da Linea di Comando

```bash
# Installa direttamente
sudo ./armnas_update_v1.2.3.run

# Installazione automatica (senza conferme)
sudo ./armnas_update_v1.2.3.run --auto-install

# Con backup personalizzato
sudo ./armnas_update_v1.2.3.run --backup /path/to/backup.tar.gz
```

## 🛡️ Sicurezza

### Verifica Integrità

- Ogni pacchetto ha un **checksum SHA256**
- Il sistema verifica l'integrità prima dell'installazione
- I pacchetti corrotti vengono rifiutati

### Backup Automatico

- Backup completo prima di ogni aggiornamento
- Possibilità di rollback tramite interfaccia web
- Backup salvati in `/opt/armnas/backups`

### Permessi

- Solo gli **amministratori** possono gestire aggiornamenti
- Installazione richiede **permessi root**
- File temporanei in directory sicure

## 🔧 Risoluzione Problemi

### Aggiornamento Fallito

1. **Controlla i log** del sistema
2. **Ripristina da backup**:
   ```bash
   # Da interfaccia web: Aggiornamenti > Backup > Ripristina
   # Da linea di comando:
   sudo tar -xzf /opt/armnas/backups/backup_file.tar.gz -C /opt
   ```

### Server Non Raggiungibile

1. Verifica la configurazione in `updates.py`
2. Controlla la connessione di rete
3. Usa l'upload manuale come alternativa

### Pacchetto Corrotto

1. Il sistema rifiuterà automaticamente pacchetti con checksum non valido
2. Ri-scarica il pacchetto
3. Verifica l'integrità del server di distribuzione

## 📋 Struttura Pacchetto .run

Un pacchetto di aggiornamento contiene:

```
armnas_update_v1.2.3.run
├── [Script di estrazione e installazione]
└── [Archivio tar.gz compresso contenente:]
    ├── metadata.json          # Informazioni versione
    ├── install.sh             # Script di installazione
    ├── backend/               # File backend Python
    ├── frontend/dist/         # File frontend compilati
    ├── *.sh                   # Script di sistema
    └── *.conf                 # File di configurazione
```

### metadata.json

```json
{
  "version": "1.2.3",
  "build_date": "2024-01-20T10:30:00",
  "changelog": [
    "Nuove funzionalità",
    "Correzioni bug",
    "Miglioramenti sicurezza"
  ],
  "critical": true,
  "components": {
    "backend": true,
    "frontend": true,
    "scripts": true,
    "configs": true
  },
  "requirements": {
    "min_version": "0.0.1",
    "python_version": "3.8+",
    "system": "linux"
  }
}
```

## 🚀 Esempi d'Uso

### Scenario 1: Rilascio Nuova Versione

```bash
# 1. Sviluppatore crea il pacchetto
./manage_updates.sh create 1.3.0 --changelog "Nuova dashboard,Miglioramenti performance"

# 2. Testa il pacchetto
./manage_updates.sh test updates/armnas_update_v1.3.0.run

# 3. Carica sul server di distribuzione
curl -X POST -H "Authorization: Bearer admin-secret-token" \
  -F "file=@updates/armnas_update_v1.3.0.run" \
  https://updates.armnas.com/api/v1/upload

# 4. Gli utenti ricevono la notifica automaticamente nell'interfaccia web
```

### Scenario 2: Aggiornamento di Emergenza

```bash
# 1. Crea pacchetto critico
./manage_updates.sh create 1.2.1 --critical --changelog "Correzione sicurezza critica"

# 2. Distribuzione immediata
# Gli utenti vedranno l'aggiornamento marcato come "CRITICO"
```

### Scenario 3: Test in Ambiente di Sviluppo

```bash
# 1. Crea pacchetto di test
./manage_updates.sh create 1.3.0-beta --source ./dev-branch

# 2. Installa localmente per test
sudo ./manage_updates.sh install updates/armnas_update_v1.3.0-beta.run

# 3. Se ci sono problemi, ripristina
# (tramite interfaccia web o backup manuale)
```

## 📞 Supporto

Per problemi o domande sul sistema di aggiornamento:

1. Controlla i **log del sistema**
2. Verifica la **configurazione**
3. Consulta questa **documentazione**
4. Usa il **sistema di backup** per il rollback se necessario

---

**Nota**: Questo sistema è progettato per ambienti Linux. Per altri sistemi operativi potrebbero essere necessarie modifiche agli script di installazione.