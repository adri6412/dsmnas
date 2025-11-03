# Sistema di Aggiornamento ArmNAS

## 📋 Panoramica

Sistema completo di aggiornamento software con:
- ✅ Upload manuale pacchetti .run
- ✅ Backup automatici pre-installazione
- ✅ Verifica integrità SHA256
- ✅ Rollback completo
- ✅ Build automatico via GitHub Actions

## 🚀 Per Utenti: Come Aggiornare

### 1. Scarica l'Aggiornamento
Vai su [GitHub Releases](https://github.com/TUO-USERNAME/TUO-REPO/releases) e scarica il file `.run`

### 2. Carica e Installa
1. Accedi come admin alla tua istanza ArmNAS
2. Vai su **Aggiornamenti** nella sidebar
3. Carica il file `.run` scaricato
4. Clicca **Installa**

### 3. Verifica
Dopo il riavvio dei servizi, verifica la versione aggiornata nel Dashboard.

## 👨‍💻 Per Sviluppatori: Come Creare una Release

### Release Automatica (Consigliato)

```bash
# 1. Commit le modifiche
git add .
git commit -m "feat: Add new feature"
git push origin main

# 2. Crea e pusha il tag
git tag -a v0.3.0 -m "Release v0.3.0"
git push origin v0.3.0

# 3. GitHub Actions farà automaticamente:
#    - Build frontend
#    - Crea pacchetto .run
#    - Genera changelog
#    - Pubblica release
```

### Release Manuale

```bash
# Crea il pacchetto localmente
python3 server-update/create_update_package_fixed.py 0.3.0 \
  --source . \
  --output ./server-update/updates \
  --changelog "Novità della versione"
```

## 📂 Struttura Pacchetti

Ogni pacchetto `.run` contiene:
- Backend Python (tutte le modifiche)
- Frontend compilato
- Script di installazione
- Metadata e checksum SHA256

## 🔧 Componenti Implementati

**Backend:** `backend/api/routes/updates.py`
- Upload manuale pacchetti
- Gestione backup
- Verifica integrità

**Frontend:** `frontend/src/views/UpdateManagement.vue`
- Interfaccia upload
- Gestione backup/restore
- Visualizzazione file scaricati

**Build:** `.github/workflows/build-release.yml`
- Build automatico su tag
- Generazione changelog
- Pubblicazione release

**Script:** `launch.sh` + `install.sh`
- Estrazione pacchetto
- Backup pre-installazione
- Aggiornamento componenti

## 🛡️ Sicurezza

- ✅ Checksum SHA256 verificato
- ✅ Backup automatico prima di ogni update
- ✅ Solo admin possono gestire aggiornamenti
- ✅ Rollback completo tramite backup

## 📊 Processo di Aggiornamento

1. **Upload** → Pacchetto caricato in `/tmp/armnas_updates`
2. **Verifica** → Checksum SHA256 controllato
3. **Backup** → Sistema attuale salvato in `/opt/armnas/backups`
4. **Installazione** → Nuovi file copiati e servizi riavviati
5. **Verifica** → Check stato servizi

## 🔄 Rollback

Se qualcosa va storto:

1. **Via Web:** Aggiornamenti → Backup → Ripristina
2. **Via CLI:**
   ```bash
   sudo tar -xzf /opt/armnas/backups/backup_*.tar.gz -C /opt
   sudo systemctl restart armnas-backend nginx
   ```

## 📝 Versionamento

Usa Semantic Versioning: `MAJOR.MINOR.PATCH`

- **MAJOR:** Breaking changes
- **MINOR:** Nuove funzionalità
- **PATCH:** Bug fixes

## 🆘 Troubleshooting

**Aggiornamento fallito?**
```bash
# Controlla i log
journalctl -u armnas-backend -f

# Ripristina ultimo backup
cd /opt/armnas/backups
ls -lht | head
sudo tar -xzf backup_*.tar.gz -C /opt
```

**Servizi non ripartono?**
```bash
sudo systemctl restart armnas-backend
sudo systemctl restart nginx
```

---

**Note:** Sistema testato su Debian 11+ e Ubuntu 20.04+

**Documentazione completa:** Vedi `RELEASE_HOWTO.md` per dettagli su come creare release

