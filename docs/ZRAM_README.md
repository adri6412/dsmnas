# zram per ARM NAS (systemd-zram-generator)

## TL;DR - Quick Start

```bash
# Installa systemd-zram-generator
sudo bash scripts/install-zram-config.sh

# Riavvia per applicare
sudo reboot

# Verifica dopo riavvio
zramctl
swapon --show

# /storage è ora libero per ZFS!
sudo zpool create storage /dev/sdX  # Funziona! ✅
```

## Cos'è systemd-zram-generator?

**systemd-zram-generator** è uno strumento integrato con systemd che crea dispositivi di storage compressi in RAM per:

1. **Swap**: Memoria virtuale compressa (invece di swap su SD)
2. **Log**: `/var/log` in RAM compressa con rotation automatica
3. **Riduzione scritture SD**: ~70-90% meno scritture sulla scheda SD

## Perché usare zram-config?

### ❌ Problema Originale con OverlayFS

```
OverlayFS (800+ righe di codice complesso)
  ↓
/storage montato in overlay/tmpfs
  ↓
ZFS: "cannot mount '/storage': directory is already mounted" ❌
```

### ✅ Soluzione con systemd-zram-generator

```
systemd-zram-generator (file config semplice)
  ↓
/storage LIBERO per ZFS ✅
Swap e log in RAM compressa ✅
Riduzione usura SD ~80% ✅
Integrato con systemd ✅
```

## Come Funziona

### Architettura Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                     RAM FISICA (es. 4GB)                     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────────────────────────┐     │
│  │  zram0       │  │  zram1                           │     │
│  │  (swap)      │  │  (/var/log overlay)              │     │
│  │              │  │                                  │     │
│  │  1GB RAM     │  │  150MB RAM                       │     │
│  │  compresso   │  │  compresso                       │     │
│  │  ↓           │  │  ↓                               │     │
│  │  ~3GB swap   │  │  ~450MB log                      │     │
│  │  virtuale    │  │  (lzo-rle)                       │     │
│  │  (lzo-rle)   │  │                                  │     │
│  └──────────────┘  └──────────────────────────────────┘     │
│                                                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │  Sistema + Applicazioni + Cache                       │ │
│  │  (resto della RAM ~2.85GB)                            │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
                           │
                           ↓
┌─────────────────────────────────────────────────────────────┐
│                     SD CARD / DISCO                          │
├─────────────────────────────────────────────────────────────┤
│  /                    - Sistema operativo (scritture ~80% ↓) │
│  /opt/armnas          - Software NAS (scrivibile ✅)         │
│  /opt/zram/oldlog     - Log vecchi (rotation automatica)    │
│  /storage             - LIBERO per ZFS ✅                    │
└─────────────────────────────────────────────────────────────┘
```

### Flusso Dati

1. **Swap**:
   ```
   Applicazione richiede memoria
     ↓
   RAM piena? → Kernel swappa pagine
     ↓
   Pagine compresse (ratio 2.5:1)
     ↓
   Salvate in zram0 (RAM compressa)
     ✅ 10-25x più veloce della SD!
   ```

2. **Log**:
   ```
   Servizio scrive log
     ↓
   Log scritti in /var/log (overlay su zram1)
     ↓
   Compressi in RAM (ratio 4:1 per testo)
     ↓
   Log vecchi ruotati in /opt/zram/oldlog (SD)
     ✅ Solo log vecchi scritti su SD!
   ```

3. **ZFS**:
   ```
   zpool create storage /dev/sdX
     ↓
   /storage libero (non in zram) ✅
     ↓
   Pool ZFS montato normalmente
     ✅ Nessun conflitto!
   ```

## Installazione

### Metodo 1: Script Automatico (Raccomandato)

```bash
# Scarica script
cd /opt/armnas
git pull  # O clone se non hai già il repo

# Esegui installazione
sudo bash scripts/install-zram-config.sh
```

Lo script:
- ✅ Clona repository zram-config da GitHub
- ✅ Installa zram-config
- ✅ Configura `/etc/ztab` ottimizzato per ARM NAS
- ✅ Crea directory `/opt/zram/oldlog`
- ✅ Abilita e avvia servizio systemd
- ✅ Verifica funzionamento

### Metodo 2: Manuale

```bash
# 1. Installa dipendenze
sudo apt-get update
sudo apt-get install -y git util-linux rsync

# 2. Clone repository
cd /tmp
git clone https://github.com/ecdye/zram-config.git
cd zram-config

# 3. Esegui installazione
sudo bash install.bash

# 4. Configura per ARM NAS
sudo cp /opt/armnas/config/ztab /etc/ztab

# 5. Crea directory log
sudo mkdir -p /opt/zram/oldlog

# 6. Abilita servizio
sudo systemctl enable zram-config
sudo systemctl start zram-config

# 7. Verifica
zramctl
swapon --show
```

## Configurazione

### File: `/etc/ztab`

```bash
# Swap: 1GB RAM → 3GB swap virtuale
swap	lzo-rle		1G		3G		75		0		150

# Log: 150MB RAM → 450MB log virtuali
log	lzo-rle		150M		450M		/var/log	/opt/zram/oldlog
```

### Parametri Swap

| Parametro | Valore | Significato |
|-----------|--------|-------------|
| `lzo-rle` | algoritmo | Compressione veloce |
| `1G` | mem_limit | Max 1GB RAM usata |
| `3G` | disk_size | 3GB swap virtuale presentato al OS |
| `75` | priority | Priorità alta (usa prima di swap su SD) |
| `0` | page-cluster | Pagine singole (bassa latenza) |
| `150` | swappiness | Usa swap aggressivamente (veloce!) |

### Parametri Log

| Parametro | Valore | Significato |
|-----------|--------|-------------|
| `lzo-rle` | algoritmo | Compressione veloce |
| `150M` | mem_limit | Max 150MB RAM usata |
| `450M` | disk_size | 450MB log virtuali |
| `/var/log` | target_dir | Directory da montare in zram |
| `/opt/zram/oldlog` | oldlog_dir | Dove salvare log vecchi (SD) |

## Verifica

### Check Rapido

```bash
# Device zram attivi
zramctl

# Output atteso:
# NAME       ALGORITHM DISKSIZE  DATA  COMPR TOTAL STREAMS MOUNTPOINT
# /dev/zram1 lzo-rle       450M 16.9M 373.2K  692K       4 /var/log
# /dev/zram0 lzo-rle         3G    4K    87B   12K       4 [SWAP]
```

### Check Dettagliato

```bash
# 1. Servizio attivo?
systemctl status zram-config
# Deve essere "active (exited)"

# 2. Swap zram funziona?
swapon --show | grep zram
# NAME       TYPE      SIZE USED PRIO
# /dev/zram0 partition   3G   0B   75

# 3. /var/log in zram?
df -h /var/log
# Filesystem     Size  Used Avail Use% Mounted on
# /dev/zram1     400M   20M  350M   6% /var/log (overlay)

# 4. /storage libero?
mountpoint /storage
# /storage is not a mountpoint  ← CORRETTO! Libero per ZFS

# 5. Statistiche compressione
cat /sys/block/zram0/mm_stat
# orig_data_size compr_data_size mem_used_total ...
```

### Check ZFS

```bash
# /storage deve essere libero
mountpoint /storage
# Deve dire "is not a mountpoint"

# Crea pool di test
sudo zpool create -f testpool /dev/sdX

# Deve funzionare senza errori! ✅

# Rimuovi test
sudo zpool destroy testpool
```

## Uso Quotidiano

### Comandi Utili

```bash
# Visualizza stato zram
zramctl

# Visualizza swap (incluso zram)
swapon --show

# Visualizza tutti i filesystem
df -h

# Visualizza memoria
free -h

# Log servizio zram
journalctl -u zram-config

# Statistiche compressione live
watch -n 1 'cat /sys/block/zram0/mm_stat'
```

### Modifica Configurazione

```bash
# 1. Ferma servizio
sudo systemctl stop zram-config

# 2. Modifica configurazione
sudo nano /etc/ztab

# 3. Riavvia servizio
sudo systemctl start zram-config

# 4. Verifica
zramctl
```

### Esempi Modifiche

#### Aumentare swap (se hai più RAM)

```bash
# Se hai 8GB RAM, puoi usare 2GB per swap
swap	lzo-rle		2G		6G		75		0		150
```

#### Usare zstd per migliore compressione log

```bash
# zstd comprime meglio il testo (4-5x vs 2-3x)
# Ma è più lento di lzo-rle
log	zstd		150M		600M		/var/log	/opt/zram/oldlog
```

#### Aggiungere /var/cache in zram

```bash
# Riduce scritture SD durante apt-get
dir	zstd		200M		600M		/var/cache
```

## Troubleshooting

### Problema: zram non si avvia

```bash
# Verifica modulo kernel
lsmod | grep zram

# Se non c'è, carica manualmente
sudo modprobe zram

# Verifica support kernel
zcat /proc/config.gz | grep ZRAM
# Deve mostrare CONFIG_ZRAM=m o CONFIG_ZRAM=y

# Riavvia servizio
sudo systemctl restart zram-config
```

### Problema: Swap zram non usato

```bash
# Verifica priorità
swapon --show

# zram deve avere priorità maggiore di swap su disco
# Se necessario, modifica /etc/ztab:
swap	lzo-rle		1G		3G		100		0		150
#                                    ↑ priorità più alta
```

### Problema: /var/log non in zram

```bash
# Verifica servizi che bloccano /var/log
sudo lsof +D /var/log

# Ferma servizi, riavvia zram
sudo systemctl stop rsyslog
sudo systemctl restart zram-config
sudo systemctl start rsyslog
```

### Problema: Out of Memory anche con swap

```bash
# Aumenta swap zram (se hai RAM disponibile)
sudo systemctl stop zram-config
sudo nano /etc/ztab
# Cambia: swap lzo-rle 2G 6G 75 0 150
sudo systemctl start zram-config

# Oppure aumenta swappiness (usa swap prima)
# Cambia: swap lzo-rle 1G 3G 75 0 200
#                                    ↑ da 150 a 200
```

## Performance

### Benchmark Tipici

| Operazione | SD Card | zram (lzo-rle) | Speedup |
|------------|---------|----------------|---------|
| Swap Read | 20 MB/s | 800 MB/s | **40x** |
| Swap Write | 15 MB/s | 400 MB/s | **27x** |
| Log Write | 25 MB/s | 400 MB/s | **16x** |
| Log Read | 40 MB/s | 800 MB/s | **20x** |

### Compressione Tipica

| Tipo Dati | Algoritmo | Ratio | Esempio |
|-----------|-----------|-------|---------|
| Swap (mix) | lzo-rle | 2.5:1 | 1GB RAM → 2.5GB swap |
| Log (testo) | lzo-rle | 3:1 | 150MB RAM → 450MB log |
| Log (testo) | zstd | 4-5:1 | 150MB RAM → 600-750MB log |
| Binari | lzo-rle | 1.5:1 | Poco comprimibili |

### Riduzione Scritture SD

| Scenario | Scritture SD/ora | Con zram | Riduzione |
|----------|------------------|----------|-----------|
| Sistema idle | ~50 MB/h | ~10 MB/h | **80%** |
| Uso normale | ~200 MB/h | ~40 MB/h | **80%** |
| Uso intensivo | ~1 GB/h | ~200 MB/h | **80%** |

## Migrazione da OverlayFS

### Step 1: Disabilita OverlayFS

```bash
# Se hai overlayfs/overlayroot configurato
sudo /opt/armnas/scripts/disable-overlayfs.sh
sudo reboot
```

### Step 2: Installa zram-config

```bash
sudo bash /opt/armnas/scripts/install-zram-config.sh
```

### Step 3: Verifica

```bash
# zram attivo?
zramctl

# /storage libero?
sudo zpool create testpool /dev/sdX  # Deve funzionare ✅
sudo zpool destroy testpool
```

### Vantaggi della Migrazione

| Aspetto | OverlayFS | zram-config | Miglioramento |
|---------|-----------|-------------|---------------|
| Complessità | 800+ righe codice | 1 file config | ✅ 99% più semplice |
| /storage per ZFS | ❌ Bloccato | ✅ Libero | ✅ Risolve problema |
| Swap performance | Su SD (~20 MB/s) | In RAM (~400 MB/s) | ✅ 20x più veloce |
| Configurazione | Scripts complessi | `/etc/ztab` | ✅ Molto più facile |
| Manutenzione | Difficile | Facile | ✅ Affidabile |

## FAQ

### Q: zram usa troppa RAM?

**A**: No. Con la configurazione default (1GB swap + 150MB log), zram usa solo ~1.15GB RAM. Su un sistema con 4GB RAM, hai ancora ~2.85GB liberi.

### Q: Cosa succede se zram si riempie?

**A**: Il kernel inizia a usare swap su disco (se configurato). Oppure, se `disk_size` è raggiunto, le applicazioni vedono "out of swap" e possono essere uccise dall'OOM killer.

### Q: I dati in zram sono persistenti?

**A**: No! zram è RAM, quindi i dati si perdono al riavvio. Per questo:
- ✅ Swap: OK (swap non deve essere persistente)
- ✅ Log: OK (log vecchi salvati in `/opt/zram/oldlog`)
- ❌ /storage: NO! (ecco perché NON va in zram)

### Q: Posso usare zram e swap su SD insieme?

**A**: Sì! zram avrà priorità maggiore (75 vs -2), quindi il kernel userà prima zram (veloce) e solo se pieno userà swap su SD (lento).

### Q: zram funziona con Docker?

**A**: Sì! Docker continua a funzionare normalmente. Anzi, beneficia di swap più veloce.

### Q: Devo riavviare per applicare modifiche a `/etc/ztab`?

**A**: No, basta riavviare il servizio:
```bash
sudo systemctl restart zram-config
```

## Link Utili

- **Repository zram-config**: https://github.com/ecdye/zram-config
- **Documentazione Kernel zram**: https://www.kernel.org/doc/Documentation/blockdev/zram.txt
- **Benchmark Compressione**: https://github.com/facebook/zstd#benchmarks
- **Community zram-config**: https://github.com/ecdye/zram-config/issues

## Conclusione

✅ **zram-config è la soluzione perfetta per ARM NAS** perché:

1. ✅ **Risolve problema ZFS**: `/storage` libero per pool ZFS
2. ✅ **Riduce usura SD**: ~80% meno scritture
3. ✅ **Migliora performance**: Swap 20x più veloce
4. ✅ **Semplice**: 1 file configurazione vs 800+ righe codice
5. ✅ **Affidabile**: Usato su migliaia di Raspberry Pi
6. ✅ **Facile manutenzione**: Modifica `/etc/ztab` e riavvia servizio

**Migra ora da OverlayFS a zram-config** per un sistema più semplice, veloce e affidabile! 🚀

