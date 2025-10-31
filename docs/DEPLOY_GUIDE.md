# 🚀 Guida al Deploy del Sistema di Aggiornamento

Questa guida ti aiuta a installare il sistema di aggiornamento su un sistema ArmNAS già funzionante.

## 📋 Prerequisiti

- Sistema ArmNAS già installato e funzionante
- Accesso root/sudo al sistema
- Python 3.8+ installato
- Node.js e npm (per ricompilare il frontend)

## 🎯 Metodi di Deploy

### Metodo 1: Deploy Automatico Completo (Raccomandato)

```bash
# 1. Copia tutti i file del sistema di aggiornamento sul server
scp -r * user@your-armnas-server:/tmp/armnas-update/

# 2. Connettiti al server
ssh user@your-armnas-server

# 3. Vai nella directory
cd /tmp/armnas-update

# 4. Esegui il deploy automatico
sudo ./deploy_update_system.sh
```

**Cosa fa lo script automatico:**
- ✅ Crea backup automatico del sistema
- ✅ Ferma i servizi temporaneamente
- ✅ Installa tutti i file necessari
- ✅ Aggiorna main.py, router.js, sidebar.vue
- ✅ Installa dipendenze Python
- ✅ Ricompila il frontend
- ✅ Riavvia i servizi
- ✅ Verifica l'installazione

### Metodo 2: Deploy Manuale Passo-Passo

Se preferisci controllare ogni passaggio:

#### Passo 1: Backup
```bash
sudo mkdir -p /opt/armnas/backups
sudo tar -czf /opt/armnas/backups/backup_$(date +%Y%m%d_%H%M%S).tar.gz -C /opt armnas
```

#### Passo 2: Copia File Backend
```bash
sudo cp backend/api/routes/updates.py /opt/armnas/backend/api/routes/
```

#### Passo 3: Aggiorna main.py
```bash
sudo nano /opt/armnas/backend/main.py
```

Aggiungi:
```python
# Nella sezione import
from api.routes import disk, users, shares, network, system, files, test, service, auth, user_system, zfs, updates

# Nella sezione router
app.include_router(updates.router, prefix="/api/updates", tags=["Aggiornamenti"], dependencies=[Depends(get_current_admin)])
```

#### Passo 4: Installa Dipendenze
```bash
cd /opt/armnas/backend
sudo pip3 install requests==2.31.0
```

#### Passo 5: Copia File Frontend
```bash
sudo cp frontend/src/views/UpdateManagement.vue /opt/armnas/frontend/src/views/
```

#### Passo 6: Aggiorna Router Frontend
```bash
sudo nano /opt/armnas/frontend/src/router/index.js
```

Aggiungi:
```javascript
// Import
import UpdateManagement from '@/views/UpdateManagement.vue'

// Rotta
{
  path: '/updates',
  name: 'UpdateManagement',
  component: UpdateManagement,
  meta: { requiresAuth: true, requiresAdmin: true }
},
```

#### Passo 7: Aggiorna Sidebar
```bash
sudo nano /opt/armnas/frontend/src/components/layout/Sidebar.vue
```

Aggiungi nel menu:
```vue
<router-link v-if="isAdmin" to="/updates" class="menu-item" :class="{ active: $route.path === '/updates' }">
  <font-awesome-icon icon="download" />
  <span v-if="!isCollapsed">{{ $t('sidebar.updates') || 'Aggiornamenti' }}</span>
</router-link>
```

#### Passo 8: Ricompila Frontend
```bash
cd /opt/armnas/frontend
npm install
npm run build
```

#### Passo 9: Copia Script di Utilità
```bash
sudo cp *.py *.sh *.md /opt/armnas/
sudo chmod +x /opt/armnas/*.py /opt/armnas/*.sh
```

#### Passo 10: Riavvia Servizi
```bash
sudo systemctl restart armnas
# oppure
sudo systemctl restart armnas-backend
```

### Metodo 3: Deploy Rapido per Test

Per test rapidi durante lo sviluppo:

```bash
./quick_deploy.sh
```

Poi completa manualmente i passaggi mancanti.

## 🔧 Configurazione Post-Deploy

### 1. Configura Server di Aggiornamenti

Modifica `/opt/armnas/backend/api/routes/updates.py`:

```python
UPDATE_CONFIG = {
    "update_server_url": "https://your-update-server.com/api/v1",
    "current_version": "0.1.0",  # Versione corrente del tuo sistema
    # ... altre configurazioni
}
```

### 2. Testa il Sistema

1. **Accedi come amministratore** all'interfaccia web
2. **Vai su "Aggiornamenti"** nel menu laterale
3. **Clicca "Controlla Aggiornamenti"**
4. **Verifica** che non ci siano errori

### 3. Configura Server di Distribuzione (Opzionale)

Se vuoi un server di aggiornamenti:

```bash
# Su un server separato
python3 /opt/armnas/update_server_example.py
```

## 🛠️ Risoluzione Problemi

### Errore: "updates module not found"

```bash
# Verifica che il file sia presente
ls -la /opt/armnas/backend/api/routes/updates.py

# Verifica import in main.py
grep "updates" /opt/armnas/backend/main.py
```

### Errore: "UpdateManagement component not found"

```bash
# Verifica che il file sia presente
ls -la /opt/armnas/frontend/src/views/UpdateManagement.vue

# Ricompila il frontend
cd /opt/armnas/frontend
npm run build
```

### Servizio non si riavvia

```bash
# Controlla i log
sudo journalctl -u armnas -f

# Oppure
tail -f /var/log/armnas.log
```

### Permessi negati

```bash
# Correggi permessi
sudo chown -R armnas:armnas /opt/armnas
sudo chmod +x /opt/armnas/*.sh /opt/armnas/*.py
```

## 🔄 Rollback

Se qualcosa va storto:

```bash
# Ripristina dal backup
sudo systemctl stop armnas
sudo tar -xzf /opt/armnas/backups/backup_YYYYMMDD_HHMMSS.tar.gz -C /opt
sudo systemctl start armnas
```

## ✅ Verifica Installazione

Dopo il deploy, verifica che tutto funzioni:

1. **Backend**: `curl http://localhost:8000/api/updates/status`
2. **Frontend**: Accedi alla pagina Aggiornamenti
3. **Script**: `cd /opt/armnas && ./manage_updates.sh list`

## 📞 Supporto

Se hai problemi:

1. Controlla i log del sistema
2. Verifica che tutti i file siano stati copiati
3. Assicurati che i servizi siano riavviati
4. Consulta `UPDATE_SYSTEM_README.md` per dettagli

---

**Nota**: Il deploy automatico è il metodo più sicuro perché include backup e rollback automatici.