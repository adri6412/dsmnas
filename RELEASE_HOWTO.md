# Come Creare una Nuova Release

## 🚀 Processo Automatico

Il sistema di release è completamente automatizzato tramite GitHub Actions. Basta creare un tag e tutto il resto viene fatto automaticamente.

### Passo 1: Prepara il Codice

1. **Assicurati che tutto sia committato:**
   ```bash
   git status
   git add .
   git commit -m "Prepare for release v0.3.0"
   ```

2. **Compila e testa localmente (opzionale ma consigliato):**
   ```bash
   # Test frontend
   cd frontend
   npm install
   npm run build
   cd ..
   
   # Test backend
   cd backend
   python3 -m pytest  # se hai test
   cd ..
   ```

### Passo 2: Crea e Pusha il Tag

```bash
# Crea il tag (sostituisci 0.3.0 con la tua versione)
git tag -a v0.3.0 -m "Release v0.3.0: Descrizione breve"

# Pusha il tag su GitHub
git push origin v0.3.0
```

### Passo 3: Attendi il Build Automatico

1. Vai su **GitHub** → **Actions** nel tuo repository
2. Vedrai un workflow "Build and Release Update Package" in esecuzione
3. Il workflow:
   - Compila il frontend
   - Crea il pacchetto .run
   - Genera automaticamente il changelog dai commit
   - Crea una release GitHub
   - Carica il pacchetto come asset della release

### Passo 4: Verifica la Release

1. Vai su **GitHub** → **Releases**
2. Troverai la nuova release con:
   - File `armnas_update_v0.3.0.run` (pacchetto di installazione)
   - File `armnas_update_v0.3.0.run.info` (informazioni e checksum)
   - Note di release automatiche con changelog
   - Istruzioni di installazione

## 📋 Schema di Versionamento

Usa [Semantic Versioning](https://semver.org/):

- **MAJOR.MINOR.PATCH** (es: 1.2.3)
  - **MAJOR**: Cambiamenti incompatibili con versioni precedenti
  - **MINOR**: Nuove funzionalità compatibili
  - **PATCH**: Bug fix compatibili

### Esempi

```bash
# Bug fix
git tag v0.2.1 -m "Bug fixes"

# Nuova funzionalità
git tag v0.3.0 -m "Add update system"

# Breaking change
git tag v1.0.0 -m "First stable release"

# Pre-release
git tag v1.0.0-beta.1 -m "Beta release"
git tag v1.0.0-rc.1 -m "Release candidate"
```

## 🔧 Personalizzazione Release

### Modificare il Changelog

Il changelog viene generato automaticamente dai messaggi di commit. Per un changelog migliore:

**Usa commit semantici:**
```bash
git commit -m "feat: Add dark mode support"
git commit -m "fix: Resolve memory leak in dashboard"
git commit -m "docs: Update installation guide"
git commit -m "chore: Update dependencies"
```

**Tipi di commit:**
- `feat`: Nuova funzionalità
- `fix`: Bug fix
- `docs`: Documentazione
- `style`: Formattazione
- `refactor`: Refactoring
- `test`: Test
- `chore`: Manutenzione

### Creare una Release Draft

Se vuoi rivedere la release prima di pubblicarla:

1. Modifica `.github/workflows/build-release.yml`
2. Cambia `draft: false` in `draft: true`
3. Dopo il build, vai su Releases e pubblica manualmente

### Aggiungere Note Manuali

Dopo la creazione automatica, puoi:
1. Andare su GitHub → Releases
2. Cliccare "Edit" sulla release
3. Aggiungere note addizionali o screenshot

## 🧪 Test della Release Localmente

Prima di creare la release ufficiale, puoi testare il processo:

```bash
# Crea un pacchetto di test
python3 server-update/create_update_package_fixed.py 0.3.0-test \
  --source . \
  --output ./server-update/updates \
  --changelog "Test release"

# Verifica il pacchetto
ls -lh server-update/updates/
cat server-update/updates/armnas_update_v0.3.0-test.run.info

# Test installazione (su macchina di test!)
sudo ./server-update/updates/armnas_update_v0.3.0-test.run
```

## ⚠️ Problemi Comuni

### Il workflow non si avvia

**Causa:** Il tag non è stato pushato
```bash
# Verifica tag locali
git tag

# Pusha il tag
git push origin v0.3.0
```

### Build fallisce

**Controlla i log su GitHub Actions:**
1. GitHub → Actions
2. Clicca sul workflow fallito
3. Leggi i log di errore

**Errori comuni:**
- Frontend non compila → Verifica `npm run build` localmente
- Script Python fallisce → Verifica dipendenze in requirements.txt
- Permessi mancanti → Verifica GITHUB_TOKEN (dovrebbe essere automatico)

### Pacchetto creato ma non caricato

Verifica che il file GITHUB_TOKEN sia configurato (è automatico per GitHub Actions)

## 🔄 Aggiornare una Release Esistente

Se devi modificare una release già pubblicata:

```bash
# Elimina il tag locale e remoto
git tag -d v0.3.0
git push origin :refs/tags/v0.3.0

# Elimina la release su GitHub (manualmente via web)

# Ricrea il tag
git tag -a v0.3.0 -m "Release v0.3.0 (updated)"
git push origin v0.3.0
```

## 📝 Checklist Pre-Release

Prima di creare una release importante:

- [ ] Tutti i test passano
- [ ] Frontend compila senza errori
- [ ] Backend funziona correttamente
- [ ] Documentazione aggiornata
- [ ] CHANGELOG.md aggiornato (opzionale)
- [ ] VERSION file aggiornato (automatico)
- [ ] Testato su ambiente di staging
- [ ] Backup creati e testati
- [ ] Note di release preparate

## 🎯 Dopo la Release

1. **Annuncia la release:** Informa gli utenti via email/social
2. **Monitora:** Controlla le issue per bug report
3. **Hotfix se necessario:** Se emergono bug critici, crea una patch release
4. **Pianifica la prossima:** Usa GitHub Projects o Issues per la roadmap

## 📚 Risorse

- [Semantic Versioning](https://semver.org/)
- [Conventional Commits](https://www.conventionalcommits.org/)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [GitHub Releases Docs](https://docs.github.com/en/repositories/releasing-projects-on-github)

---

**Esempio Completo di Release:**

```bash
# 1. Completa le modifiche
git add .
git commit -m "feat: Add automatic update system with GitHub releases"

# 2. Pusha su GitHub
git push origin main

# 3. Crea e pusha il tag
git tag -a v0.3.0 -m "Release v0.3.0: Automatic update system"
git push origin v0.3.0

# 4. Attendi il build su GitHub Actions (3-5 minuti)

# 5. La release è pronta! 🎉
# Vai su: https://github.com/TUO-USERNAME/TUO-REPO/releases
```

## 🚀 Prima Release Pubblica

Per la prima release v1.0.0:

```bash
# Aggiorna VERSION
echo "1.0.0" > VERSION
git add VERSION
git commit -m "chore: Bump version to 1.0.0"

# Crea tag v1.0.0
git tag -a v1.0.0 -m "First public release v1.0.0"

# Pusha tutto
git push origin main
git push origin v1.0.0

# 🎉 La prima release pubblica è pronta!
```

