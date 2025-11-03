# Migrazione da OverlayFS a zram-config

## 🚨 Importante Aggiornamento del Sistema

**A partire da questa versione, il sistema ARM NAS NON usa più OverlayFS, ma zram-config.**

## Perché il Cambio?

### ❌ Problemi con OverlayFS

1. **Conflitto con ZFS**: overlayfs montava `/storage` in modo che ZFS non potesse usarlo
   ```
   Error: cannot mount '/storage': directory is already mounted
   ```

2. **Complessità eccessiva**: 
   - ~800 righe di codice bash complesso
   - Script `/usr/local/bin/overlay-rw` e `/usr/local/bin/overlay-ro`
   - Servizi systemd multipli
   - Difficile da debuggare e mantenere

3. **Problemi di mount**:
   - `/opt/armnas` doveva essere montato con bind mount dalla SD originale
   - Gestione complessa di lower/upper directories
   - Difficoltà nel passare da RO a RW mode

### ✅ Vantaggi di zram-config

1. **ZFS funziona**: `/storage` è libero per pool ZFS
2. **Semplicità**: 1 file di configurazione (`/etc/ztab`) invece di 800+ righe di script
3. **Performance**: Swap in RAM compressa (20-40x più veloce della SD)
4. **Affidabilità**: Progetto maturo, usato su migliaia di Raspberry Pi
5. **Manutenzione facile**: Nessuno script complesso, solo configurazione

## Cosa Cambia?

### Prima (con OverlayFS)

```
┌────────────────────────────────────────┐
│ Root Filesystem (SD Card)              │
├────────────────────────────────────────┤
│                                        │
│  Overlay su tutto /                    │
│  ├─ lower: SD originale (RO)           │
│  ├─ upper: RAM o SD (RW)               │
│  └─ merged: /                          │
│                                        │
│  /opt/armnas → bind mount dalla SD     │
│  /storage → BLOCCATO da overlay ❌     │
│                                        │
└────────────────────────────────────────┘
```

### Dopo (con zram-config)

```
┌────────────────────────────────────────┐
│ Root Filesystem (SD Card)              │
├────────────────────────────────────────┤
│                                        │
│  Nessun overlay - tutto normale ✅     │
│                                        │
│  /opt/armnas → scrivibile normalmente  │
│  /storage → LIBERO per ZFS ✅          │
│                                        │
├────────────────────────────────────────┤
│ zram Devices (RAM compressa)           │
├────────────────────────────────────────┤
│                                        │
│  /dev/zram0 → Swap (1GB RAM → 3GB)     │
│  /dev/zram1 → /var/log overlay         │
│                                        │
└────────────────────────────────────────┘
```

## Migrazione Automatica

### Nuove Installazioni

**Le nuove installazioni usano automaticamente zram-config!**

Quando esegui `scripts/install.sh`, il sistema:
1. ✅ NON configura più overlayfs
2. ✅ Installa e configura zram-config automaticamente
3. ✅ Lascia `/storage` libero per ZFS

### Installazioni Esistenti

Se hai già un sistema con overlayfs, devi migrare manualmente.

#### Opzione 1: Reinstallazione Completa (Raccomandato)

```bash
# Backup dei dati importanti
sudo tar -czf /tmp/armnas-backup.tar.gz /opt/armnas

# Reinstalla con la nuova versione
sudo bash scripts/install.sh

# Verifica
zramctl  # Deve mostrare zram attivo
mountpoint /storage  # Deve dire "is not a mountpoint"
sudo zpool create testpool /dev/sdX  # Deve funzionare ✅
```

#### Opzione 2: Migrazione Manuale

```bash
# 1. Disabilita overlayfs se presente
if [ -f /etc/overlayroot.conf ]; then
    echo 'overlayroot=""' | sudo tee /etc/overlayroot.conf
fi

# 2. Rimuovi servizi overlayfs legacy
sudo systemctl disable bind-armnas.service 2>/dev/null || true
sudo systemctl disable overlayfs.service 2>/dev/null || true

# 3. Rimuovi script overlayfs
sudo rm -f /usr/local/bin/overlay-rw
sudo rm -f /usr/local/bin/overlay-ro
sudo rm -f /usr/local/bin/overlay-status
sudo rm -f /usr/local/bin/bind-armnas.sh
sudo rm -f /usr/local/bin/setup-overlayfs.sh

# 4. Riavvia per applicare modifiche
sudo reboot

# 5. Dopo il riavvio, installa zram-config
sudo bash /opt/armnas/scripts/install-zram-config.sh

# 6. Verifica
zramctl
swapon --show
mountpoint /storage  # Deve essere libero!
```

## Verifica Migrazione

### 1. Verifica che overlayfs NON sia attivo

```bash
mount | grep overlay
# Non deve mostrare overlay su /
```

### 2. Verifica che zram sia attivo

```bash
zramctl
# Deve mostrare /dev/zram0 (swap) e /dev/zram1 (log)

swapon --show
# Deve mostrare /dev/zram0 con priorità 75
```

### 3. Verifica che /storage sia libero

```bash
mountpoint /storage
# Deve dire: "/storage is not a mountpoint"

# Test ZFS
sudo zpool create -f testpool /dev/sdX
# Deve funzionare senza errori! ✅

sudo zpool destroy testpool
```

### 4. Verifica che /opt/armnas sia scrivibile

```bash
sudo touch /opt/armnas/.test && sudo rm /opt/armnas/.test && echo "✅ OK"
```

## File e Script Modificati

### Script di Installazione

**`scripts/install.sh`** è stato modificato:

- ❌ Rimosso: Configurazione completa di overlayfs (~800 righe)
- ✅ Aggiunto: Chiamata a `scripts/install-zram-config.sh`
- ✅ Semplificato: Funzione `ensure_armnas_rw()` ora solo verifica scrivibilità

### Backend

**`backend/api/utils/overlayfs.py`** è stato deprecato:

- Le funzioni esistono ancora per compatibilità
- Ritornano sempre valori che indicano filesystem scrivibile
- Mostrano warning se usate
- **Non rimuovere** per non rompere import esistenti

### Build Script

**`live-build/build.sh`** non è stato modificato:

- Lo script di build ISO non usa overlayfs
- Non richiede modifiche

## FAQ Migrazione

### Q: Devo reinstallare tutto?

**A**: No, puoi migrare manualmente (vedi "Opzione 2: Migrazione Manuale" sopra).

### Q: I miei dati in /opt/armnas sono al sicuro?

**A**: Sì! Con zram-config, `/opt/armnas` scrive normalmente sulla SD. Non c'è overlay che potrebbe perdere dati.

### Q: E i miei pool ZFS esistenti?

**A**: Se hai già pool ZFS che non potevi usare a causa di overlayfs, ora funzioneranno! Basta importarli:
```bash
sudo zpool import -a
```

### Q: Overlayfs non funzionava sul mio sistema, posso solo usare zram?

**A**: Sì! zram-config funziona su tutti i sistemi Linux moderni (kernel 3.14+). È più compatibile di overlayfs.

### Q: Le performance sono migliori?

**A**: Sì!
- Swap: 20-40x più veloce (RAM vs SD)
- Log: 10-20x più veloce
- Nessun overhead di overlayfs
- Root filesystem accesso diretto (no layer overlay)

### Q: Posso ancora usare modalità RO/RW come prima?

**A**: Con zram-config, non serve più! Il root filesystem è sempre scrivibile, ma:
- Swap va in RAM compressa (non su SD)
- Log vanno in RAM compressa (rotation automatica su SD)
- Scritture su SD ridotte dell'80% comunque

Se vuoi comunque una modalità RO completa, puoi configurare overlayroot manualmente, ma **non è raccomandato** perché causa conflitti con ZFS.

### Q: Cosa succede se lo script install-zram-config.sh fallisce?

**A**: Il sistema funziona comunque normalmente, ma senza la protezione zram per la SD. Puoi:
1. Verificare i log: `journalctl -u zram-config`
2. Installare manualmente zram-config (vedi ZRAM_README.md)
3. Chiedere supporto su GitHub Issues

## Rollback (Se Necessario)

**Non raccomandato**, ma se vuoi tornare a overlayfs:

```bash
# 1. Disinstalla zram-config
sudo systemctl stop zram-config
sudo systemctl disable zram-config
sudo rm -f /etc/ztab

# 2. Reinstalla vecchia versione ARM NAS (prima del cambio)
git checkout <vecchia-versione>
sudo bash scripts/install.sh

# 3. Riavvia
sudo reboot
```

⚠️ **Attenzione**: Tornando a overlayfs, ZFS non funzionerà più su `/storage`!

## Supporto

Se hai problemi con la migrazione:

1. **Verifica documentazione**: Leggi `ZRAM_README.md`
2. **Check logs**: `journalctl -u zram-config` e `dmesg | grep zram`
3. **GitHub Issues**: Apri un issue con dettagli del problema
4. **Community**: Chiedi su forum/Discord del progetto

## Conclusione

✅ La migrazione da overlayfs a zram-config è un **grande miglioramento**:

- Più semplice (1 file config vs 800+ righe codice)
- Più veloce (swap in RAM compressa)
- Più affidabile (progetto maturo)
- **ZFS funziona finalmente!** 🎉

Benvenuto nel nuovo ARM NAS con zram-config! 🚀

