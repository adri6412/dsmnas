# Setup Virtual DSM con ArmNAS

Questa guida spiega come configurare e utilizzare Virtual DSM con ArmNAS.

## Prerequisiti

Prima di iniziare, assicurati che il sistema abbia:

1. **Docker installato** - Lo script di installazione lo fa automaticamente
2. **Docker Compose** - Installato automaticamente dallo script
3. **KVM support** - Necessario per la virtualizzazione
4. **ZFS configurato** - Per lo storage sottostante

## Verifica Supporto KVM

Per verificare che il tuo sistema supporti KVM:

```bash
# Installa cpu-checker se non è già installato
sudo apt-get install cpu-checker

# Verifica KVM
sudo kvm-ok
```

Se ricevi errori:
- Verifica che la virtualizzazione sia abilitata nel BIOS (Intel VT-x o AMD SVM)
- Se stai usando una VM, abilita la virtualizzazione annidata
- I cloud provider spesso non supportano la virtualizzazione annidata

## Avvio Virtual DSM

Una volta installato ArmNAS, puoi avviare Virtual DSM:

### Metodo 1: Via Interfaccia Web

1. Accedi all'interfaccia ArmNAS
2. Vai su "Virtual DSM" nella sidebar
3. Clicca su "Avvia" per avviare il container
4. Attendi che il container si avvii (può richiedere alcuni minuti)
5. Clicca sull'URL di accesso quando disponibile

### Metodo 2: Via Docker Compose

```bash
cd /opt/armnas
docker compose up -d
```

## Accesso a Virtual DSM

Dopo l'avvio:

1. Apri il browser e vai su `http://localhost:5000` (o l'IP del server:5000)
2. Segui il wizard di installazione DSM
3. Imposta username e password admin
4. Configura il sistema secondo le tue necessità

## Storage Virtual DSM

Virtual DSM utilizza una directory locale per lo storage:

- Directory: `/opt/armnas/virtual-dsm-storage`
- Dimensione iniziale: 256 GB (modificabile in docker-compose.yml)
- I dati persisteranno anche dopo il riavvio del container

## Configurazione Docker Compose

Il file `docker-compose.yml` si trova in `/opt/armnas/`:

```yaml
services:
  virtual-dsm:
    container_name: virtual-dsm
    image: vdsm/virtual-dsm
    environment:
      DISK_SIZE: "256G"  # Modifica qui la dimensione
    devices:
      - /dev/kvm
      - /dev/net/tun
    cap_add:
      - NET_ADMIN
    ports:
      - 5000:5000  # Porta Web UI
    volumes:
      - ./virtual-dsm-storage:/storage
    restart: always
    stop_grace_period: 2m
```

## Gestione Container

### Avvio
```bash
docker compose start virtual-dsm
# oppure via UI: Virtual DSM > Avvia
```

### Fermata
```bash
docker compose stop virtual-dsm
# oppure via UI: Virtual DSM > Ferma
```

### Riavvio
```bash
docker compose restart virtual-dsm
# oppure via UI: Virtual DSM > Riavvia
```

### Visualizzazione Log
```bash
docker logs -f virtual-dsm
# oppure via UI: Virtual DSM > Visualizza Log
```

## Compatibilità Hardware

Virtual DSM funziona meglio con:

- **CPU**: Intel con VT-x o AMD con SVM
- **RAM**: Minimo 2 GB per DSM, 4 GB consigliati
- **Storage**: Preferibilmente SSD per migliori performance
- **OS**: Linux con kernel 5.4+

## Limitazioni Nota

Da [virtual-dsm GitHub](https://github.com/vdsm/virtual-dsm):

> **Disclaimer**: Solo installare questo container su hardware Synology, qualsiasi altro uso non è consentito dalla loro EULA.

Assicurati di rispettare la licenza Synology quando utilizzi Virtual DSM.

## Troubleshooting

### Container non si avvia

1. Verifica KVM: `sudo kvm-ok`
2. Controlla i log: `docker logs virtual-dsm`
3. Verifica Docker: `docker ps -a`
4. Controlla permessi: `ls -l /dev/kvm`

### Porta 5000 già in uso

Modifica la porta in docker-compose.yml:
```yaml
ports:
  - 5001:5000  # Usa porta 5001 invece di 5000
```

### Performance lente

- Aumenta RAM allocata
- Usa SSD invece di HDD
- Verifica che KVM sia attivo

### Container si blocca

```bash
docker compose down
docker compose up -d
```

## Risorse Utili

- [Virtual DSM GitHub](https://github.com/vdsm/virtual-dsm)
- [Documentazione Synology DSM](https://kb.synology.com/)
- [ArmNAS GitHub](link-al-repo)

## Supporto

Per problemi con:
- **ArmNAS**: Apri un issue sul repository ArmNAS
- **Virtual DSM**: Apri un issue su [virtual-dsm GitHub](https://github.com/vdsm/virtual-dsm)
- **DSM**: Consulta la documentazione Synology

