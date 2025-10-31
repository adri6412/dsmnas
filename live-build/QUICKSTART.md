# Quickstart: Build ISO Debian con Virtual DSM

Questa guida rapida ti permette di creare un'immagine ISO Debian installabile con supporto ZFS e Virtual DSM pre-configurato.

## Requisiti Rapid Check

```bash
# Verifica prerequisiti
which lb && echo "✓ live-build OK" || echo "✗ live-build mancante"
which debootstrap && echo "✓ debootstrap OK" || echo "✗ debootstrap mancante"
[ -f "../scripts/installer_dsm.sh" ] && echo "✓ installer_dsm.sh trovato" || echo "✗ installer_dsm.sh mancante"
```

## Build ISO in 3 Passi

### 1. Installa Prerequisiti

```bash
sudo apt-get update
sudo apt-get install -y live-build live-boot live-config debian-keyring debootstrap
```

### 2. Esegui Build

```bash
cd live-build
sudo ./build.sh
```

### 3. Pulisci e Ricompila

```bash
# Pulisci build precedente
sudo lb clean --purge

# Ricompila con le modifiche
sudo ./build.sh
```

### 4. Testa ISO

```bash
# Scrivi su USB
sudo dd if=binary-hybrid.iso of=/dev/sdX bs=4M status=progress

# Oppure testa in VirtualBox
```

## Cosa Include l'ISO

✓ **Debian Bookworm** con kernel recente  
✓ **ZFS completo** (pool, dataset, snapshot)  
✓ **Docker & Compose** pre-installati  
✓ **Virtual DSM auto-installer**  
✓ **Autologin temporaneo** per prima installazione  
✓ **Debian Installer** per installazione su disco fisso  

## Flusso di Installazione

```
Boot ISO
   ↓
Menu Grub: Install Debian oppure Live System
   ↓
   ├─→ [Install] Debian Installer normale
   │
   └─→ [Live System] Boot con autologin root
        ↓
        auto-install-dsm.service avvia
        ↓
        installer_dsm.sh --auto
        ↓
        Disabilita autologin
        ↓
        Reboot senza autologin
```

## Dettagli Configurazione

### Debian Installer

L'ISO include il **Debian Installer** completo grazie all'opzione:
```bash
--debian-installer live
```

Questo significa:
- Menu boot con opzione "Install"
- Installazione standard Debian su disco fisso
- Uso normale di calamares/debconf
- Supporto partizionamento ZFS nativo

### Live System

Il live system ha:
- Autologin come root su tty1
- Systemd service che avvia installer
- Disabilitazione automatica dopo installazione
- Configurazione persistente

## Personalizzazione

### Aggiungere Pacchetti

Edita `build.sh`, funzione `add_packages()`:
```bash
cat >> config/package-lists/zfs-nas.list.chroot << 'EOF'
mio-pacchetto
EOF
```

### Modificare Autologin

Edita `build.sh`, funzione `setup_autologin()`:
```bash
--autologin TUOUSUR
```

### Cambiare Distribuzione

Modifica in `configure_build()`:
```bash
--distribution bullseye  # o sid, trixie, etc.
```

## Troubleshooting

### Build Fallisce

```bash
# Vedi logs
tail -100 build.log

# Pulisci e riprova
sudo ./build.sh
```

### ISO non si Avvia

```bash
# Verifica signature
sudo lb binary_checksums

# Test in VM
qemu-system-x86_64 -cdrom binary-hybrid.iso -boot d
```

### Autologin non Funziona

Verifica systemd:
```bash
ls -la config/includes.chroot/etc/systemd/system/getty@tty1.service.d/
```

### Installazione DSM Fallisce

```bash
# Vedi logs su sistema live
journalctl -u auto-install-dsm.service -f
```

## Building su Altri OS

### Ubuntu

```bash
sudo apt-get install live-build debian-archive-keyring
cd live-build
sudo ./build.sh
```

### Debian Derivative

```bash
# Aggiungi source.list Debian
echo "deb http://deb.debian.org/debian bookworm main" | sudo tee /etc/apt/sources.list.d/debian.list
sudo apt-get update
sudo apt-get install live-build
```

## Dimensione ISO

Aspettati:
- **~1.5-2GB** ISO finale (compressa xz)
- **~15-20GB** spazio temporaneo durante build
- **~10-15 minuti** su SSD veloce
- **~30-60 minuti** su HDD

## Post-Build

Dopo il build riuscito:

```bash
# Info ISO
isoinfo -i binary-hybrid.iso -d

# Verifica checksum
md5sum binary-hybrid.iso > binary-hybrid.iso.md5

# Copia su USB
sudo dd if=binary-hybrid.iso of=/dev/sdX bs=4M conv=fsync
```

## Supporto

Problemi? Controlla:
1. `build.log` per errori
2. `README.md` per documentazione completa
3. Logs systemd se ISO si avvia ma DSM non installa

## Licenze

- Debian: DFSG compliant
- ZFS: CDDL (incompatibile con GPL)
- Virtual DSM: EULA Synology
- ArmNAS: MIT (componenti propri)

---

**Happy Building! 🎉**

