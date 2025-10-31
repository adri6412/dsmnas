# Guida Creazione installer_dsm.sh con Makeself

## Prerequisiti

1. Installa makeself:
```bash
# Su Debian/Ubuntu
sudo apt-get install makeself

# Oppure scarica da: https://github.com/megastep/makeself
```

## Creazione installer_dsm.sh

### Metodo 1: Dalla directory del progetto

Se sei nella directory contenente `nas/`:

```bash
./makeself.sh ../nas/ installer_dsm.sh "VirtualDSM Installer" ./scripts/install.sh
```

### Metodo 2: Dalla root del progetto nas/

```bash
cd nas
../makeself.sh . installer_dsm.sh "VirtualDSM Installer" ./scripts/install.sh
```

### Parametri

- `../nas/` o `.` = Directory da comprimere (root del progetto)
- `installer_dsm.sh` = Nome del file output
- `"VirtualDSM Installer"` = Label/descrizione
- `./scripts/install.sh` = Script da eseguire dopo l'estrazione

## Posizionamento

Dopo la creazione, sposta `installer_dsm.sh` in `scripts/`:

```bash
mv installer_dsm.sh scripts/
```

## Verifica

```bash
# Verifica che sia un file makeself valido
file scripts/installer_dsm.sh

# Dovresti vedere: "Makeself self-extracting archive"
```

## Uso nell'ISO

L'`installer_dsm.sh` viene automaticamente incluso nell'ISO durante il build con `live-build/build.sh`.

Lo script `auto-install-dsm.sh` lo cerca in:
- `/root/installer_dsm.sh`
- `/opt/installer_dsm.sh`

E lo esegue in modalità automatica: `installer_dsm.sh --auto`

## Struttura Attesa

Lo script `install.sh` si aspetta questa struttura quando viene estratto:

```
/tmp/xxx/  (directory temporanea estratta da makeself)
├── backend/
│   ├── api/
│   ├── main.py
│   └── requirements.txt
├── frontend/
│   ├── src/
│   └── package.json
├── scripts/
│   ├── install.sh  (questo script)
│   ├── fix_*.sh
│   └── ...
├── config/
│   ├── docker-compose.yml
│   └── nginx-armnas.conf
└── docs/
```

## Risoluzione Problemi

### Errore: "Impossibile trovare la directory root del progetto"

Lo script `install.sh` cerca automaticamente la root del progetto. Se vedi questo errore:

1. Verifica che makeself abbia compresso tutta la struttura corretta
2. Verifica che quando viene estratto, la struttura sia completa
3. Controlla i log dell'estrazione makeself

### Test Manuale

Puoi testare l'estrazione senza eseguire:

```bash
mkdir /tmp/test_extract
cd /tmp/test_extract
sh /path/to/installer_dsm.sh --keep --target /tmp/test_extract
ls -la
# Dovresti vedere: backend/, frontend/, scripts/, config/, docs/
```

