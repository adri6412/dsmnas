# Live-Build per ArmNAS con Virtual DSM

Questo sistema crea un'immagine Debian installabile con:
- Supporto ZFS completo
- Docker pre-installato
- Auto-installazione Virtual DSM al primo avvio
- Autologin temporaneo che si disattiva dopo l'installazione

## Requisiti

- Debian/Ubuntu con root access
- Almeno 20GB di spazio su disco
- Connessione internet stabile
- Almeno 8GB di RAM consigliati

## Installazione Prerequisiti

```bash
sudo apt-get update
sudo apt-get install live-build debian-keyring live-boot live-config debootstrap debian-archive-keyring
```

## Uso

### Metodo Rapido

```bash
cd live-build
chmod +x bootstrap.sh build.sh
sudo ./build.sh
```

### Metodo Manuale

```bash
cd live-build

# 1. Configura il sistema
sudo ./bootstrap.sh

# 2. Copia installer_dsm.sh nella directory di build
sudo cp ../scripts/installer_dsm.sh config/includes.chroot/root/

# 3. Build l'immagine ISO
sudo lb build

# 4. Trova l'immagine generata
ls -lh binary-hybrid.iso
```

## Struttura File

```
live-build/
├── README.md                    # Questa documentazione
├── bootstrap.sh                 # Configurazione live-build
├── build.sh                     # Script di build completo
├── auto-install-dsm.sh          # Script auto-installazione
└── config/                      # Generato da bootstrap.sh
```

## Funzionamento

1. **Boot**: L'ISO si avvia con autologin come root
2. **Auto-install**: Il servizio systemd `auto-install-dsm.service` avvia automaticamente `auto-install-dsm.sh`
3. **Installazione**: Lo script esegue `installer_dsm.sh --auto`
4. **Disabilitazione**: Dopo l'installazione, autologin viene disabilitato
5. **Reboot**: Il sistema si riavvia senza autologin

## Configurazione

### Modificare Pacchetti

Edita `config/package-lists/zfs-nas.list.chroot`:

```
# Aggiungi pacchetti qui
mio-pacchetto
altro-pacchetto
```

### Modificare Configurazione Sistema

Crea file in `config/includes.chroot/`:

```bash
config/includes.chroot/etc/mia-configurazione.conf
```

### Aggiungere Hook Personalizzati

Crea hook in `config/hooks/`:

```bash
cat > config/hooks/0999-mio-hook.hook.chroot << 'EOF'
#!/bin/bash
# Il mio hook personalizzato
echo "Hook eseguito!"
EOF
chmod +x config/hooks/0999-mio-hook.hook.chroot
```

## Customizzazione

### Cambiare Autologin User

Modifica `setup_autologin()` in `bootstrap.sh`:

```bash
ExecStart=-/sbin/agetty --autologin TUOUSUR --noclear %I $TERM
```

### Aggiungere Post-Install Scripts

Aggiungi file eseguibili in `config/includes.chroot/usr/local/bin/`:

```bash
cat > config/includes.chroot/usr/local/bin/mio-script.sh << 'EOF'
#!/bin/bash
echo "Post-install script"
EOF
chmod +x config/includes.chroot/usr/local/bin/mio-script.sh
```

## Troubleshooting

### Build Fallisce

```bash
# Pulisci build precedenti
sudo lb clean --purge

# Verifica logs
sudo lb build 2>&1 | tee build.log
```

### ISO non si Avvia

Verifica UEFI/Legacy boot:

```bash
# UEFI
isohybrid -u binary-hybrid.iso

# Legacy
isohybrid binary-hybrid.iso
```

### Autologin non Funziona

Verifica configurazione systemd:

```bash
cat config/includes.chroot/etc/systemd/system/getty@tty1.service.d/autologin.conf
```

### ZFS non Funziona

Verifica che i pacchetti siano installati:

```bash
grep -A 100 "package-lists/zfs" config/
```

## Testing

### Test in VirtualBox

```bash
# Crea VM con:
# - 4GB RAM
# - 100GB HDD
# - UEFI abilitato
# - Boot da ISO generata
```

### Test su Hardware Reale

```bash
# Usa dd per scrivere su USB
sudo dd if=binary-hybrid.iso of=/dev/sdX bs=4M status=progress

# Oppure con etcher/rufus
```

## Note Importanti

1. **installer_dsm.sh**: Deve essere un file makeself valido
2. **Spazio**: Il build richiede molto spazio (~15-20GB)
3. **Tempo**: Il build può richiedere 30-60 minuti
4. **Network**: Durante il build serve connessione internet

## Licenze

- Debian: Licenza Debian
- ZFS: CDDL
- Docker: Apache 2.0
- Virtual DSM: EULA Synology (solo hardware Synology)

## Supporto

Per problemi:
1. Verifica i log di build
2. Controlla configurazione
3. Prova con build pulita
4. Apri issue sul repository

