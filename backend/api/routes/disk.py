from fastapi import APIRouter, HTTPException
import psutil
import subprocess
import shutil
import os
import re
from pydantic import BaseModel
from typing import List, Dict, Optional, Tuple

router = APIRouter()

class DiskInfo(BaseModel):
    device: str
    mountpoint: str
    fstype: Optional[str] = ""  # Modificato per consentire valori None o vuoti
    total: int
    used: int
    free: int
    percent: float
    automount: Optional[bool] = False

class DiskOperation(BaseModel):
    operation: str  # mount, unmount, format, set_automount
    device: str
    mountpoint: Optional[str] = None
    fstype: Optional[str] = None
    automount: Optional[bool] = False

@router.get("/info", response_model=List[DiskInfo])
async def get_disk_info():
    """
    Ottiene informazioni sui dischi collegati al sistema
    """
    disk_info = []

    try:
        # Ottieni tutti i dispositivi di blocco, inclusi quelli non montati
        lsblk_output = subprocess.run(
            ["lsblk", "-o", "NAME,TYPE,SIZE,MOUNTPOINT,FSTYPE", "--json"],
            capture_output=True, text=True, check=True
        )

        import json
        block_devices = json.loads(lsblk_output.stdout)

        # Aggiungi i dispositivi montati con informazioni complete
        partitions = psutil.disk_partitions(all=True)
        for partition in partitions:
            if partition.device.startswith('/dev/'):
                try:
                    usage = psutil.disk_usage(partition.mountpoint)
                    # Gestisci il caso in cui fstype è None
                    fstype = partition.fstype
                    if fstype is None:
                        fstype = ""

                    # Verifica se il disco è configurato per l'auto mount
                    is_automount = await check_automount(partition.device)

                    disk_info.append(DiskInfo(
                        device=partition.device,
                        mountpoint=partition.mountpoint,
                        fstype=fstype,
                        total=usage.total,
                        used=usage.used,
                        free=usage.free,
                        percent=usage.percent,
                        automount=is_automount
                    ))
                except PermissionError:
                    # Alcuni punti di mount potrebbero non essere accessibili
                    pass

        # Aggiungi i dispositivi non montati
        for device in block_devices.get("blockdevices", []):
            if device["type"] == "disk" or device["type"] == "part":
                device_path = f"/dev/{device['name']}"
                # Verifica se il dispositivo è già stato aggiunto (perché montato)
                if not any(d.device == device_path for d in disk_info):
                    # Dispositivo non montato
                    # Gestisci il caso in cui fstype è None
                    fstype = device.get("fstype", "")
                    if fstype is None:
                        fstype = ""

                    # Verifica se il disco è configurato per l'auto mount
                    is_automount = await check_automount(device_path)

                    disk_info.append(DiskInfo(
                        device=device_path,
                        mountpoint="",
                        fstype=fstype,
                        total=0,  # Non possiamo ottenere queste informazioni per dispositivi non montati
                        used=0,
                        free=0,
                        percent=0,
                        automount=is_automount
                    ))
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nel recupero delle informazioni sui dischi: {str(e)}")

    return disk_info

@router.post("/operation", response_model=Dict[str, str])
async def disk_operation(operation: DiskOperation):
    """
    Esegue operazioni sui dischi (montaggio, smontaggio, formattazione, auto mount)
    """
    try:
        if operation.operation == "mount":
            if not operation.mountpoint:
                raise HTTPException(status_code=400, detail="Punto di montaggio non specificato")

            # Crea la directory di montaggio se non esiste
            subprocess.run(["mkdir", "-p", operation.mountpoint], check=True)

            # Monta il disco
            cmd = ["mount"]
            if operation.fstype:
                cmd.extend(["-t", operation.fstype])
            cmd.extend([operation.device, operation.mountpoint])

            subprocess.run(cmd, check=True)

            # Se automount è abilitato, configura il disco per il montaggio automatico
            if operation.automount:
                await configure_automount(operation.device, operation.mountpoint, operation.fstype)

            return {"status": "success", "message": f"Disco {operation.device} montato su {operation.mountpoint}"}

        elif operation.operation == "unmount":
            subprocess.run(["umount", operation.device], check=True)
            return {"status": "success", "message": f"Disco {operation.device} smontato"}

        elif operation.operation == "format":
            if not operation.fstype:
                raise HTTPException(status_code=400, detail="Tipo di filesystem non specificato")

            # Formatta il disco
            if operation.fstype == "ext4":
                subprocess.run(["mkfs.ext4", operation.device], check=True)
            elif operation.fstype == "ntfs":
                subprocess.run(["mkfs.ntfs", operation.device], check=True)
            else:
                raise HTTPException(status_code=400, detail=f"Tipo di filesystem non supportato: {operation.fstype}")

            return {"status": "success", "message": f"Disco {operation.device} formattato con {operation.fstype}"}

        elif operation.operation == "set_automount":
            if not operation.mountpoint:
                raise HTTPException(status_code=400, detail="Punto di montaggio non specificato")

            if operation.automount:
                # Configura il disco per il montaggio automatico
                await configure_automount(operation.device, operation.mountpoint, operation.fstype)
                return {"status": "success", "message": f"Auto mount configurato per {operation.device} su {operation.mountpoint}"}
            else:
                # Rimuovi la configurazione di auto mount
                await remove_automount(operation.device)
                return {"status": "success", "message": f"Auto mount disabilitato per {operation.device}"}

        else:
            raise HTTPException(status_code=400, detail=f"Operazione non supportata: {operation.operation}")

    except subprocess.CalledProcessError as e:
        raise HTTPException(status_code=500, detail=f"Errore nell'esecuzione del comando: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nell'operazione sul disco: {str(e)}")

async def check_automount(device: str) -> bool:
    """
    Verifica se un dispositivo è configurato per il montaggio automatico
    """
    try:
        # Controlla se il dispositivo è presente in /etc/fstab
        with open("/etc/fstab", "r") as f:
            fstab_content = f.read()

        # Cerca il dispositivo in fstab
        return bool(re.search(rf"^{re.escape(device)}\s+", fstab_content, re.MULTILINE))
    except Exception as e:
        print(f"Errore nel controllo dell'auto mount: {str(e)}")
        return False

async def get_device_uuid(device: str) -> str:
    """
    Ottiene l'UUID del dispositivo
    """
    try:
        result = subprocess.run(["blkid", "-s", "UUID", "-o", "value", device],
                               capture_output=True, text=True, check=True)
        return result.stdout.strip()
    except Exception:
        return ""

async def configure_automount(device: str, mountpoint: str, fstype: Optional[str] = None) -> None:
    """
    Configura un dispositivo per il montaggio automatico
    """
    try:
        # Ottieni l'UUID del dispositivo
        uuid = await get_device_uuid(device)

        # Se non è possibile ottenere l'UUID, usa il percorso del dispositivo
        device_id = f"UUID={uuid}" if uuid else device

        # Determina il tipo di filesystem
        if not fstype or fstype == "auto":
            try:
                result = subprocess.run(["blkid", "-s", "TYPE", "-o", "value", device],
                                      capture_output=True, text=True, check=True)
                fstype = result.stdout.strip()
            except Exception:
                fstype = "auto"

        # Crea la directory di montaggio se non esiste
        os.makedirs(mountpoint, exist_ok=True)

        # Prepara la riga da aggiungere a fstab
        fstab_line = f"{device_id} {mountpoint} {fstype} defaults 0 0\n"

        # Rimuovi eventuali configurazioni esistenti per questo dispositivo
        await remove_automount(device)

        # Aggiungi la nuova configurazione a fstab
        with open("/etc/fstab", "a") as f:
            f.write(fstab_line)

    except Exception as e:
        raise HTTPException(status_code=500,
                           detail=f"Errore nella configurazione dell'auto mount: {str(e)}")

async def remove_automount(device: str) -> None:
    """
    Rimuove la configurazione di auto mount per un dispositivo
    """
    try:
        # Ottieni l'UUID del dispositivo
        uuid = await get_device_uuid(device)

        # Leggi il contenuto attuale di fstab
        with open("/etc/fstab", "r") as f:
            fstab_lines = f.readlines()

        # Filtra le righe, rimuovendo quelle che contengono il dispositivo
        if uuid:
            new_fstab = [line for line in fstab_lines
                        if not (device in line or f"UUID={uuid}" in line)]
        else:
            new_fstab = [line for line in fstab_lines if device not in line]

        # Scrivi il nuovo contenuto
        with open("/etc/fstab", "w") as f:
            f.writelines(new_fstab)

    except Exception as e:
        raise HTTPException(status_code=500,
                           detail=f"Errore nella rimozione dell'auto mount: {str(e)}")

@router.get("/health", response_model=Dict[str, str])
async def check_disk_health(device: str):
    """
    Controlla lo stato di salute del disco usando smartctl
    """
    try:
        result = subprocess.run(["smartctl", "-H", device], capture_output=True, text=True, check=False)
        return {"status": "success", "health": result.stdout}
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nel controllo della salute del disco: {str(e)}")