import subprocess
import json
import os
from typing import List, Dict, Optional, Any

def run_command(command: List[str]) -> Dict[str, Any]:
    """
    Esegue un comando e restituisce l'output come dizionario
    """
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True
        )
        return {
            "success": True,
            "output": result.stdout.strip(),
            "error": None
        }
    except subprocess.CalledProcessError as e:
        return {
            "success": False,
            "output": None,
            "error": e.stderr.strip() if e.stderr else str(e)
        }

def get_zfs_pools() -> List[Dict[str, Any]]:
    """
    Ottiene l'elenco dei pool ZFS
    """
    cmd_result = run_command(["zpool", "list", "-H", "-o", "name,size,allocated,free,capacity,health,altroot", "-p"])
    
    if not cmd_result["success"]:
        return []
    
    pools = []
    for line in cmd_result["output"].splitlines():
        if not line.strip():
            continue
            
        parts = line.split("\t")
        if len(parts) >= 7:
            pools.append({
                "name": parts[0],
                "size": int(parts[1]),
                "allocated": int(parts[2]),
                "free": int(parts[3]),
                "capacity": parts[4].rstrip("%"),
                "health": parts[5],
                "altroot": parts[6] if parts[6] != "-" else None
            })
    
    return pools

def get_zfs_datasets() -> List[Dict[str, Any]]:
    """
    Ottiene l'elenco dei dataset ZFS
    """
    cmd_result = run_command(["zfs", "list", "-H", "-o", "name,used,avail,refer,mountpoint", "-p"])
    
    if not cmd_result["success"]:
        return []
    
    datasets = []
    for line in cmd_result["output"].splitlines():
        if not line.strip():
            continue
            
        parts = line.split("\t")
        if len(parts) >= 5:
            datasets.append({
                "name": parts[0],
                "used": int(parts[1]),
                "available": int(parts[2]),
                "referenced": int(parts[3]),
                "mountpoint": parts[4]
            })
    
    return datasets

def get_available_disks() -> List[Dict[str, Any]]:
    """
    Ottiene l'elenco dei dischi disponibili per la creazione di pool ZFS
    """
    # Ottieni tutti i dispositivi di blocco
    cmd_result = run_command(["lsblk", "-d", "-o", "NAME,SIZE,MODEL,SERIAL,TYPE"])
    
    if not cmd_result["success"]:
        return []
    
    try:
        # Prova a interpretare l'output come JSON
        try:
            data = json.loads(cmd_result["output"])
            blockdevices = data.get("blockdevices", [])
        except json.JSONDecodeError:
            # Se non è JSON, interpreta l'output come testo
            lines = cmd_result["output"].strip().split('\n')
            if len(lines) <= 1:
                return []
                
            # Salta l'intestazione
            blockdevices = []
            for line in lines[1:]:
                parts = line.split()
                if len(parts) >= 5 and parts[-1] == "disk":
                    blockdevices.append({
                        "name": parts[0],
                        "size": parts[1],
                        "model": " ".join(parts[2:-2]) if len(parts) > 5 else "",
                        "type": "disk"
                    })
        
        disks = []
        for device in blockdevices:
            if device.get("type") == "disk":
                # Verifica se il disco è già utilizzato in un pool ZFS
                in_use = False
                check_result = run_command(["zpool", "status"])
                if check_result["success"] and device["name"] in check_result["output"]:
                    in_use = True
                
                disks.append({
                    "name": device["name"],
                    "path": f"/dev/{device['name']}",
                    "size": device.get("size", ""),
                    "model": device.get("model", "").strip(),
                    "serial": device.get("serial", "").strip() if "serial" in device else "",
                    "in_use": in_use
                })
        
        return disks
    except Exception as e:
        print(f"Errore in get_available_disks: {str(e)}")
        return []

def create_zfs_pool(name: str, raid_type: str, disks: List[str], mount_point: Optional[str] = None) -> Dict[str, Any]:
    """
    Crea un nuovo pool ZFS
    
    Args:
        name: Nome del pool
        raid_type: Tipo di RAID (mirror, raidz, raidz2, raidz3, stripe)
        disks: Lista dei percorsi dei dischi
        mount_point: Punto di montaggio (opzionale)
    
    Returns:
        Dizionario con il risultato dell'operazione
    """
    if not name or not raid_type or not disks:
        return {
            "success": False,
            "error": "Nome del pool, tipo di RAID e dischi sono obbligatori"
        }
    
    # Verifica che il nome del pool sia valido
    if not name.isalnum() and not all(c in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_" for c in name):
        return {
            "success": False,
            "error": "Il nome del pool può contenere solo lettere, numeri, trattini e underscore"
        }
    
    # Se mount_point è /storage, verifica se esiste già un pool montato su /storage
    # Permettiamo solo UN pool montato su /storage alla volta
    actual_mount_point = mount_point
    if mount_point == "/storage":
        # Controlla se esiste già un pool montato su /storage controllando i dataset
        # Il pool root appare come dataset con lo stesso nome del pool
        datasets = get_zfs_datasets()
        for dataset in datasets:
            dataset_mountpoint = dataset.get("mountpoint")
            dataset_name = dataset.get("name")
            
            # Se troviamo un dataset con mountpoint /storage
            if dataset_mountpoint == "/storage":
                # Verifica se è un pool root (nome senza "/")
                if "/" not in dataset_name:
                    # È un pool root montato su /storage
                    return {
                        "success": False,
                        "error": f"Esiste già un pool ZFS ('{dataset_name}') montato su /storage. Solo un pool alla volta può essere montato su /storage. Elimina o smonta il pool esistente prima di crearne uno nuovo."
                    }
    
    # Verifica generale se il mountpoint è già in uso (per altri mountpoint)
    elif mount_point:
        datasets = get_zfs_datasets()
        for dataset in datasets:
            if dataset.get("mountpoint") == mount_point:
                # Il mountpoint è già utilizzato
                return {
                    "success": False,
                    "error": f"Il mountpoint '{mount_point}' è già utilizzato da '{dataset.get('name')}'. Scegli un mountpoint diverso."
                }
    
    # Se il mountpoint è /storage, verifica che non sia in overlay
    if actual_mount_point == "/storage":
        # Crea la directory se non esiste (importante per overlayroot)
        if not os.path.exists("/storage"):
            try:
                os.makedirs("/storage", mode=0o755)
            except Exception as e:
                return {
                    "success": False,
                    "error": f"Impossibile creare la directory /storage: {str(e)}. Verifica i permessi."
                }
        
        # Verifica che /storage non sia montato da overlayroot o overlay
        # Questo è importante perché overlayroot può interferire con ZFS
        try:
            mount_check = subprocess.run(
                ["findmnt", "-n", "-o", "SOURCE,FSTYPE", "/storage"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if mount_check.returncode == 0 and mount_check.stdout.strip():
                mount_info = mount_check.stdout.strip().split()
                if len(mount_info) >= 2:
                    mount_source = mount_info[0]
                    mount_fstype = mount_info[1]
                    # Se è montato da overlay, avvisa ma continua (bind mount lo risolverà)
                    if "overlay" in mount_fstype.lower():
                        # Questo potrebbe essere un problema, ma il bind mount dovrebbe risolverlo
                        # al prossimo riavvio quando bind-armnas.service viene eseguito
                        pass
        except FileNotFoundError:
            # findmnt non disponibile, continua comunque
            pass
        except Exception:
            # Errore nel controllo, continua comunque
            pass
    
    # Costruisci il comando in base al tipo di RAID
    command = ["zpool", "create"]
    
    # Aggiungi il punto di montaggio se specificato
    if actual_mount_point:
        command.extend(["-m", actual_mount_point])
    
    # Aggiungi il nome del pool
    command.append(name)
    
    # Aggiungi la configurazione RAID
    if raid_type == "stripe":
        # Stripe (RAID 0) - nessun parametro aggiuntivo
        command.extend(disks)
    elif raid_type == "mirror":
        # Mirror (RAID 1)
        command.append("mirror")
        command.extend(disks)
    elif raid_type in ["raidz", "raidz1", "raidz2", "raidz3"]:
        # RAIDZ (RAID 5, 6, 7)
        command.append(raid_type)
        command.extend(disks)
    else:
        return {
            "success": False,
            "error": f"Tipo di RAID non supportato: {raid_type}"
        }
    
    # Esegui il comando
    result = run_command(command)
    
    if result["success"]:
        message = f"Pool ZFS '{name}' creato con successo"
        if actual_mount_point:
            message += f" e montato su '{actual_mount_point}'"
        
        # Se il pool è montato su /storage, configura automaticamente Docker per usare /storage/docker
        if actual_mount_point == "/storage":
            try:
                # Importa qui per evitare import circolari
                from .docker_utils import get_docker_data_root, configure_docker_data_root
                
                # Verifica se Docker è installato
                from .docker_utils import is_docker_installed
                if is_docker_installed():
                    # Ottieni il data-root corrente
                    current_config = get_docker_data_root()
                    
                    # Se Docker non è ancora configurato su /storage/docker, configuralo
                    if current_config.get("success") and current_config.get("data_root") != "/storage/docker":
                        # Crea la directory /storage/docker se non esiste
                        docker_dir = "/storage/docker"
                        if not os.path.exists(docker_dir):
                            os.makedirs(docker_dir, mode=0o755)
                        
                        # Configura Docker per usare /storage/docker
                        docker_config_result = configure_docker_data_root(docker_dir)
                        if docker_config_result.get("success"):
                            # Riavvia Docker automaticamente per applicare la configurazione
                            restart_result = run_command(["systemctl", "restart", "docker"])
                            if restart_result["success"]:
                                message += ". Docker configurato automaticamente per usare /storage/docker come data-root e riavviato."
                            else:
                                message += ". Docker configurato automaticamente per usare /storage/docker come data-root. Riavvia Docker manualmente per applicare le modifiche."
            except Exception as e:
                # Se c'è un errore nella configurazione Docker, non fallire la creazione del pool
                # Solo aggiungi un avviso nel messaggio
                message += f". Nota: Errore nella configurazione automatica di Docker: {str(e)}"
        
        return {
            "success": True,
            "message": message,
            "pool_name": name
        }
    else:
        # Migliora il messaggio di errore se è relativo al mountpoint
        error_msg = result["error"]
        if "mountpoint" in error_msg.lower() or "already mounted" in error_msg.lower():
            error_msg = f"Impossibile montare il pool su '{mount_point}': il mountpoint potrebbe essere già in uso. " + error_msg
        
        return {
            "success": False,
            "error": error_msg
        }

def destroy_zfs_pool(name: str, force: bool = False) -> Dict[str, Any]:
    """
    Distrugge un pool ZFS
    
    Args:
        name: Nome del pool
        force: Se True, forza la distruzione anche se il pool è in uso
    
    Returns:
        Dizionario con il risultato dell'operazione
    """
    if not name:
        return {
            "success": False,
            "error": "Il nome del pool è obbligatorio"
        }
    
    # Verifica che il pool esista
    pools = get_zfs_pools()
    pool_exists = any(pool["name"] == name for pool in pools)
    
    if not pool_exists:
        return {
            "success": False,
            "error": f"Pool ZFS '{name}' non trovato"
        }
    
    command = ["zpool", "destroy"]
    
    if force:
        command.append("-f")
    
    command.append(name)
    
    result = run_command(command)
    
    if result["success"]:
        return {
            "success": True,
            "message": f"Pool ZFS '{name}' distrutto con successo"
        }
    else:
        # Migliora il messaggio di errore
        error_msg = result["error"]
        if "cannot destroy" in error_msg.lower() and "dataset is busy" in error_msg.lower():
            error_msg = f"Impossibile eliminare il pool '{name}': il pool è in uso. Usa l'opzione 'force' per forzare l'eliminazione."
        elif "no such pool" in error_msg.lower():
            error_msg = f"Pool ZFS '{name}' non trovato"
        
        return {
            "success": False,
            "error": error_msg
        }

def create_zfs_dataset(pool_name: str, dataset_name: str, mount_point: Optional[str] = None, 
                       quota: Optional[str] = None, compression: Optional[str] = None) -> Dict[str, Any]:
    """
    Crea un nuovo dataset ZFS
    
    Args:
        pool_name: Nome del pool
        dataset_name: Nome del dataset
        mount_point: Punto di montaggio (opzionale)
        quota: Quota per il dataset (opzionale)
        compression: Tipo di compressione (opzionale)
    
    Returns:
        Dizionario con il risultato dell'operazione
    """
    full_name = f"{pool_name}/{dataset_name}"
    command = ["zfs", "create"]
    
    # Aggiungi le opzioni
    if mount_point:
        command.extend(["-o", f"mountpoint={mount_point}"])
    
    if quota:
        command.extend(["-o", f"quota={quota}"])
    
    if compression:
        command.extend(["-o", f"compression={compression}"])
    
    command.append(full_name)
    
    result = run_command(command)
    
    if result["success"]:
        return {
            "success": True,
            "message": f"Dataset ZFS '{full_name}' creato con successo",
            "dataset_name": full_name
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def destroy_zfs_dataset(name: str, recursive: bool = False, force: bool = False) -> Dict[str, Any]:
    """
    Distrugge un dataset ZFS
    
    Args:
        name: Nome del dataset
        recursive: Se True, distrugge anche tutti i dataset figli
        force: Se True, forza la distruzione anche se il dataset è in uso
    
    Returns:
        Dizionario con il risultato dell'operazione
    """
    command = ["zfs", "destroy"]
    
    if recursive:
        command.append("-r")
    
    if force:
        command.append("-f")
    
    command.append(name)
    
    result = run_command(command)
    
    if result["success"]:
        return {
            "success": True,
            "message": f"Dataset ZFS '{name}' distrutto con successo"
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def get_zfs_pool_status(name: str) -> Dict[str, Any]:
    """
    Ottiene lo stato dettagliato di un pool ZFS
    
    Args:
        name: Nome del pool
    
    Returns:
        Dizionario con le informazioni sul pool
    """
    result = run_command(["zpool", "status", name])
    
    if result["success"]:
        return {
            "success": True,
            "status": result["output"]
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def get_zfs_pool_properties(name: str) -> Dict[str, Any]:
    """
    Ottiene le proprietà di un pool ZFS
    
    Args:
        name: Nome del pool
    
    Returns:
        Dizionario con le proprietà del pool
    """
    result = run_command(["zpool", "get", "all", name, "-H"])
    
    if not result["success"]:
        return {
            "success": False,
            "error": result["error"]
        }
    
    properties = {}
    for line in result["output"].splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            properties[parts[1]] = parts[2]
    
    return {
        "success": True,
        "properties": properties
    }

def get_zfs_dataset_properties(name: str) -> Dict[str, Any]:
    """
    Ottiene le proprietà di un dataset ZFS
    
    Args:
        name: Nome del dataset
    
    Returns:
        Dizionario con le proprietà del dataset
    """
    result = run_command(["zfs", "get", "all", name, "-H"])
    
    if not result["success"]:
        return {
            "success": False,
            "error": result["error"]
        }
    
    properties = {}
    for line in result["output"].splitlines():
        parts = line.split("\t")
        if len(parts) >= 3:
            properties[parts[1]] = parts[2]
    
    return {
        "success": True,
        "properties": properties
    }