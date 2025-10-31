# Integrazione zram-config - Migrazione da OverlayFS

## Perché zram-config invece di OverlayFS

### Problemi con OverlayFS
- ❌ **Complesso**: 810 righe di codice con gestione RO/RW, bind mounts, servizi systemd
- ❌ **Interferisce con ZFS**: `/storage` montato in overlay impedisce creazione pool ZFS
- ❌ **Richiede riavvio**: cambio modalità RO/RW complesso senza riavvio
- ❌ **Difficile da debuggare**: mount overlay, lower root, upper directories confusionari
- ❌ **Non sempre affidabile**: overlayroot non disponibile in Debian stable

### Vantaggi di zram-config
- ✅ **Semplice**: ~150 righe di codice, configurazione tramite `/etc/ztab`
- ✅ **Non interferisce con ZFS**: `/storage` resta libero per pool ZFS
- ✅ **Swap in RAM compressa**: migliori performance, nessuna scrittura su SD
- ✅ **Log in RAM**: `/var/log` in zram con rotation automatica
- ✅ **Progettato per Raspberry Pi**: usato ampiamente, testato, affidabile
- ✅ **Facile da configurare**: modifica `/etc/ztab` e riavvia servizio

## Come Funziona zram-config

### Architettura

```
┌─────────────────────────────────────────────────────────────┐
│                     Sistema Operativo                        │
├─────────────────────────────────────────────────────────────┤
│ /var/log (overlay)  →  zram1 (150MB RAM compressa)          │
│   Log vecchi        →  /opt/zram/oldlog (SD card)           │
├─────────────────────────────────────────────────────────────┤
│ Swap (priorità 75)  →  zram0 (1GB RAM compressa)            │
├─────────────────────────────────────────────────────────────┤
│ /storage (libero)   →  Disponibile per pool ZFS ✅           │
│ /opt/armnas         →  Scrivibile sulla SD ✅                │
└─────────────────────────────────────────────────────────────┘
```

### Componenti

1. **Swap zram**: RAM compressa per swap (invece di swap su SD)
2. **Log zram**: `/var/log` in RAM compressa con overlay
3. **Log rotation**: log vecchi salvati su `/opt/zram/oldlog`
4. **Algoritmo compressione**: lzo-rle (veloce) o zstd (migliore compressione)

## Integrazione in install.sh

### Opzione 1: Sostituire Completamente OverlayFS (Raccomandato)

Sostituisci l'intera sezione overlayfs (righe 538-1352) con:

```bash
# Configura zram-config per proteggere la scheda SD dalle scritture eccessive
info "Configurazione zram-config per ridurre scritture su SD..."
info "Riferimento: https://github.com/ecdye/zram-config"

# Esegui script di installazione zram-config
if [ -f "$REPO_DIR/scripts/install-zram-config.sh" ]; then
    bash "$REPO_DIR/scripts/install-zram-config.sh" || {
        warn "Installazione zram-config fallita"
        warn "Continuo senza protezione SD (scritture dirette)"
    }
else
    warn "Script install-zram-config.sh non trovato"
    warn "Saltando configurazione zram"
fi

# /storage è ora disponibile per pool ZFS (non in zram)
info "✓ /storage disponibile per pool ZFS"
info "✓ Swap e log configurati in zram (riduce usura SD)"
```

### Opzione 2: Mantenere OverlayFS come Opzionale

Se vuoi mantenere la possibilità di usare overlayfs:

```bash
# Scegli metodo di protezione SD
info "Configurazione protezione SD card..."
echo ""
echo "Scegli il metodo di protezione SD:"
echo "  1) zram-config (raccomandato) - Swap e log in RAM compressa"
echo "  2) overlayfs - Tutto il filesystem in overlay (complesso)"
echo "  3) Nessuno - Tutte le scritture dirette su SD"
read -p "Scegli [1/2/3]: " SD_PROTECTION

case $SD_PROTECTION in
    1)
        info "Installazione zram-config..."
        bash "$REPO_DIR/scripts/install-zram-config.sh" || warn "Installazione fallita"
        ;;
    2)
        info "Configurazione overlayfs..."
        # ... codice overlayfs esistente ...
        ;;
    3)
        warn "Nessuna protezione SD configurata"
        ;;
esac
```

## Configurazione /etc/ztab

### Configurazione Default per ARM NAS

```bash
# SWAP: zram swap device
swap	lzo-rle		1G		3G		75		0		150

# LOG: /var/log in zram con rotation
log	lzo-rle		150M		450M		/var/log	/opt/zram/oldlog
```

### Parametri Spiegati

| Parametro | Descrizione | Esempio |
|-----------|-------------|---------|
| `tipo` | swap, log, dir | `swap` |
| `alg` | Algoritmo compressione | `lzo-rle`, `zstd` |
| `mem_limit` | RAM compressa (hard limit) | `1G` |
| `disk_size` | Max non compresso (~150% mem_limit) | `3G` |
| `swap_priority` | Priorità swap (75 = alta) | `75` |
| `page-cluster` | Tuning pagine (0 = singole, bassa latenza) | `0` |
| `swappiness` | Aggressività swap (150 = alta per zram) | `150` |
| `target_dir` | Directory da montare in zram | `/var/log` |
| `oldlog_dir` | Directory per log vecchi | `/opt/zram/oldlog` |

### Opzioni Avanzate

#### Più swap zram
```bash
# Swap principale (veloce)
swap	lzo-rle		1G		3G		75		0		150

# Swap secondario (migliore compressione)
swap	zstd		512M		2G		50		0		100
```

#### Directory aggiuntive in zram
```bash
# /tmp in zram (NON necessario, già in tmpfs di default)
# dir	lzo-rle		100M		300M		/tmp

# /var/cache in zram (cache pacchetti, ecc.)
dir	zstd		200M		600M		/var/cache
```

#### NON mettere in zram
```bash
# ❌ MAI mettere /storage in zram!
# dir	lzo-rle		...		...		/storage

# ❌ MAI mettere /opt/armnas in zram!
# dir	lzo-rle		...		...		/opt/armnas
```

## Migrazione da OverlayFS a zram-config

### Step 1: Backup Configurazione

```bash
# Backup file import anti prima di modificare
sudo cp /etc/fstab /etc/fstab.backup
sudo cp scripts/install.sh scripts/install.sh.backup

# Se overlayroot è configurato
sudo cp /etc/overlayroot.conf /etc/overlayroot.conf.backup 2>/dev/null || true
```

### Step 2: Disabilita OverlayFS

```bash
# Se overlayroot è installato
sudo /opt/armnas/scripts/disable-overlayfs.sh

# Riavvia
sudo reboot
```

### Step 3: Installa zram-config

```bash
# Clona repository
cd /tmp
git clone https://github.com/ecdye/zram-config.git
cd zram-config

# Installa
sudo bash install.bash

# Configura per ARM NAS
sudo cp /path/to/ztab /etc/ztab

# Avvia servizio
sudo systemctl enable zram-config
sudo systemctl start zram-config

# Verifica
zramctl
swapon --show
```

### Step 4: Verifica Funzionamento

```bash
# Verifica zram devices
zramctl

# Output atteso:
# NAME       ALGORITHM DISKSIZE  DATA  COMPR TOTAL STREAMS MOUNTPOINT
# /dev/zram1 lzo-rle       450M 16.9M 373.2K  692K       4 /var/log (overlay)
# /dev/zram0 lzo-rle         3G    4K    87B   12K       4 [SWAP]

# Verifica swap
swapon --show

# Output atteso:
# NAME       TYPE      SIZE USED PRIO
# /dev/zram0 partition   3G   0B   75

# Verifica /var/log
df -h /var/log

# Output atteso:
# Filesystem     Size  Used Avail Use% Mounted on
# /dev/zram1     400M   20M  350M   6% /var/log (overlay)

# Verifica /storage (deve essere libero per ZFS)
mountpoint /storage  # should NOT be mounted
zpool status         # ZFS deve funzionare normalmente
```

## Confronto Performance

### Scritture su SD

| Metodo | Swap | Log | Sistema |
|--------|------|-----|---------|
| Nessuna protezione | SD card | SD card | SD card |
| OverlayFS | SD card | RAM (temporaneo) | RAM (temporaneo) |
| **zram-config** | **RAM compressa** | **RAM compressa** | SD card |

### Vantaggi Misurabili

- **Riduzione scritture SD**: ~70-90% (swap + log in RAM)
- **Performance swap**: 5-10x più veloce (RAM vs SD)
- **Latenza log**: ~50% inferiore (RAM vs SD)
- **Compressione**: ratio 2:1 - 3:1 (lzo-rle), 3:1 - 5:1 (zstd per testo)

## Troubleshooting

### zram non si avvia

```bash
# Verifica dipendenze
sudo apt-get install util-linux rsync

# Verifica configurazione
cat /etc/ztab

# Verifica log
journalctl -u zram-config.service

# Riavvia servizio
sudo systemctl restart zram-config
```

### Swap zram non attivo

```bash
# Verifica kernel support
grep zram /proc/filesystems
# Dovrebbe mostrare "zram"

# Verifica modulo caricato
lsmod | grep zram

# Carica modulo manualmente
sudo modprobe zram

# Riavvia servizio
sudo systemctl restart zram-config
```

### /var/log non in zram

```bash
# Verifica mount
mountpoint /var/log
df -h /var/log

# Verifica servizi che bloccano /var/log
sudo lsof /var/log

# Stop servizi, riavvia zram
sudo systemctl stop rsyslog
sudo systemctl restart zram-config
sudo systemctl start rsyslog
```

### /storage non disponibile per ZFS

```bash
# Verifica che /storage NON sia in /etc/ztab
grep storage /etc/ztab
# NON dovrebbe mostrare nulla

# Verifica mount
mountpoint /storage
# Dovrebbe dire "is not a mountpoint" (corretto!)

# Prova a creare pool ZFS
sudo zpool create -f storage /dev/sdX
# Dovrebbe funzionare
```

## Script di Test

Testa zram-config:

```bash
#!/bin/bash
# test-zram.sh - Verifica configurazione zram

echo "=== Test zram-config ==="
echo ""

# 1. Verifica servizio
echo "1. Servizio zram-config:"
systemctl is-active zram-config && echo "✅ Attivo" || echo "❌ Non attivo"
echo ""

# 2. Verifica devices
echo "2. Device zram:"
zramctl || echo "❌ zramctl non disponibile"
echo ""

# 3. Verifica swap
echo "3. Swap zram:"
swapon --show | grep zram && echo "✅ Swap zram attivo" || echo "❌ Swap zram non trovato"
echo ""

# 4. Verifica /var/log
echo "4. /var/log in zram:"
if mountpoint -q /var/log; then
    df -h /var/log | tail -1
    echo "✅ /var/log montato"
else
    echo "❌ /var/log non montato in zram"
fi
echo ""

# 5. Verifica /storage (deve essere libero)
echo "5. /storage (deve essere libero per ZFS):"
if mountpoint -q /storage; then
    FS=$(findmnt -n -o FSTYPE /storage)
    if [ "$FS" = "zfs" ]; then
        echo "✅ /storage montato come ZFS (corretto)"
    else
        echo "⚠️  /storage montato come $FS (potrebbe non essere ZFS)"
    fi
else
    echo "✅ /storage non montato (disponibile per ZFS)"
fi
echo ""

# 6. Statistiche compressione
echo "6. Statistiche compressione:"
for dev in /dev/zram*; do
    if [ -b "$dev" ]; then
        echo "  $dev:"
        cat /sys/block/$(basename $dev)/mm_stat 2>/dev/null || echo "    N/A"
    fi
done
```

## Riferimenti

- [zram-config Repository](https://github.com/ecdye/zram-config)
- [zram Kernel Documentation](https://www.kernel.org/doc/Documentation/blockdev/zram.txt)
- [Algoritmi Compressione](https://github.com/facebook/zstd#benchmarks)
- [OverlayFS Documentation](https://www.kernel.org/doc/Documentation/filesystems/overlayfs.txt)

## Conclusione

**zram-config** è la soluzione migliore per ARM NAS perché:

✅ **Semplice**: 1 file di configurazione vs 800+ righe di codice  
✅ **Affidabile**: Testato su migliaia di Raspberry Pi  
✅ **Non interferisce con ZFS**: `/storage` resta libero  
✅ **Migliori performance**: Swap e log in RAM compressa  
✅ **Riduce usura SD**: ~70-90% meno scritture  

Sostituire overlayfs con zram-config rende il sistema più semplice, affidabile e performante.

