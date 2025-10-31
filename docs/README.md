# ArmNAS

ArmNAS è un software web per gestire un box Linux ARM come un NAS. Utilizza ZFS per la gestione dello storage e integra Virtual DSM in Docker per fornire funzionalità avanzate di NAS.

## Caratteristiche

- **Gestione ZFS**: Pool, dataset e snapshot
- **Virtual DSM**: Interfaccia Synology DSM tramite Docker
- Supporto per protocolli di condivisione file: CIFS (Samba), FTP, SFTP
- Gestione utenti
- File manager web integrato
- Gestione della rete
- Interfaccia web responsive
- Sistema di aggiornamento automatico
- Docker support per container virtualizzati

## Requisiti di sistema

- Dispositivo ARM/Linux con supporto KVM
- Python 3.8+
- Node.js 14+
- Docker e Docker Compose
- ZFS support
- Almeno 2GB di RAM disponibili per Virtual DSM

## Installazione

Per installare ArmNAS, esegui lo script di installazione:

```bash
chmod +x install.sh
sudo ./install.sh
```

Lo script installerà tutte le dipendenze necessarie, configurerà i servizi e avvierà il sistema.

## Struttura del progetto

- `/backend`: API e servizi Python per la gestione del sistema
  - FastAPI per le API REST
  - Moduli per la gestione di disco, utenti, condivisioni, rete, sistema e file

- `/frontend`: Interfaccia utente web basata su Vue.js
  - Vue 3 con Composition API
  - Vuex per la gestione dello stato
  - Vue Router per la navigazione
  - Bootstrap per lo stile

## Accesso

Dopo l'installazione, puoi accedere all'interfaccia web all'indirizzo:

```
http://<indirizzo-ip-del-dispositivo>
```

Credenziali di default:
- Username: admin
- Password: admin

## Funzionalità principali

### Gestione ZFS
- Creazione e gestione pool ZFS
- Configurazione RAID (mirror, raidz, raidz2, raidz3, stripe)
- Creazione dataset con quote e compressione
- Monitoraggio della salute e dello spazio
- Snapshot e gestione backup

### Virtual DSM
- Esecuzione di Synology DSM in container Docker
- Avvio/fermata/riavvio container
- Visualizzazione log
- Gestione storage virtualizzato

### Gestione utenti
- Creazione, modifica ed eliminazione di utenti
- Gestione dei gruppi
- Impostazione delle password

### Condivisioni
- Configurazione di condivisioni Samba (CIFS)
- Gestione del server FTP
- Configurazione SFTP
- Creazione di utenti dedicati per FTP/SFTP

### Rete
- Configurazione delle interfacce di rete
- Impostazione DNS
- Configurazione del nome host
- Test di connettività

### Sistema
- Monitoraggio delle risorse di sistema
- Gestione dei servizi
- Aggiornamento del sistema automatico
- Backup e ripristino
- Riavvio e spegnimento
- Gestione container Docker

### File manager
- Navigazione nei file
- Upload e download
- Operazioni di copia, spostamento, rinomina ed eliminazione
- Gestione dei permessi

## Licenza

Questo progetto è distribuito con licenza MIT.