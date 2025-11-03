from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
import os
import re
from ..auth import get_current_admin
from ..utils.overlayfs import ensure_rw_mode, is_filesystem_writable
from ..utils.docker_utils import (
    is_docker_installed,
    get_container_status,
    start_container,
    stop_container,
    restart_container,
    get_container_logs,
    compose_up,
    compose_down,
    compose_ps,
    is_kvm_available,
    get_docker_version,
    get_docker_compose_version,
    check_compose_available,
    get_docker_data_root,
    configure_docker_data_root,
    migrate_docker_data
)

router = APIRouter()

# Modelli Pydantic
class ContainerAction(BaseModel):
    container_name: str

class ContainerLogs(BaseModel):
    container_name: str
    tail: int = 100

class VirtualDSMConfig(BaseModel):
    disk_size: str
    host_serial: Optional[str] = None
    guest_serial: Optional[str] = None
    vm_net_mac: Optional[str] = None

# Endpoint per verificare se Docker è installato
@router.get("/status", response_model=Dict[str, Any])
async def get_docker_status(current_admin = Depends(get_current_admin)):
    """
    Verifica lo stato di Docker sul sistema
    """
    docker_installed = is_docker_installed()
    compose_available = check_compose_available() if docker_installed else False
    kvm_available = is_kvm_available() if docker_installed else False
    
    result = {
        "docker_installed": docker_installed,
        "compose_available": compose_available,
        "kvm_available": kvm_available
    }
    
    if docker_installed:
        version_result = get_docker_version()
        if version_result["success"]:
            result["docker_version"] = version_result["version"]
        
        if compose_available:
            compose_version_result = get_docker_compose_version()
            if compose_version_result["success"]:
                result["compose_version"] = compose_version_result["version"]
    
    return result

# Endpoint per ottenere lo stato di un container
@router.get("/container/{container_name}", response_model=Dict[str, Any])
async def get_container_info(container_name: str, current_admin = Depends(get_current_admin)):
    """
    Ottiene informazioni su un container Docker
    """
    result = get_container_status(container_name)
    
    if not result["success"]:
        raise HTTPException(status_code=404, detail=result.get("error", "Container non trovato"))
    
    return result

# Endpoint per avviare un container
@router.post("/container/start", response_model=Dict[str, Any])
async def start_docker_container(action: ContainerAction, current_admin = Depends(get_current_admin)):
    """
    Avvia un container Docker. Se il container non esiste, lo crea prima con docker compose.
    """
    import os
    working_dir = "/opt/armnas"
    result = start_container(action.container_name, working_dir)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nell'avvio del container"))
    
    return result

# Endpoint per fermare un container
@router.post("/container/stop", response_model=Dict[str, Any])
async def stop_docker_container(action: ContainerAction, current_admin = Depends(get_current_admin)):
    """
    Ferma un container Docker
    """
    result = stop_container(action.container_name)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nella fermata del container"))
    
    return result

# Endpoint per riavviare un container
@router.post("/container/restart", response_model=Dict[str, Any])
async def restart_docker_container(action: ContainerAction, current_admin = Depends(get_current_admin)):
    """
    Riavvia un container Docker
    """
    result = restart_container(action.container_name)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nel riavvio del container"))
    
    return result

# Endpoint per ottenere i log di un container
@router.post("/container/logs", response_model=Dict[str, Any])
async def get_docker_container_logs(request: ContainerLogs, current_admin = Depends(get_current_admin)):
    """
    Ottiene i log di un container Docker
    """
    result = get_container_logs(request.container_name, request.tail)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nel recupero dei log"))
    
    return result

# Endpoint per avviare i container con docker compose
@router.post("/compose/up", response_model=Dict[str, Any])
async def docker_compose_up(current_admin = Depends(get_current_admin)):
    """
    Avvia i container con docker compose
    """
    result = compose_up()
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nell'avvio dei container"))
    
    return result

# Endpoint per fermare i container con docker compose
@router.post("/compose/down", response_model=Dict[str, Any])
async def docker_compose_down(current_admin = Depends(get_current_admin)):
    """
    Ferma i container con docker compose
    """
    result = compose_down()
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nella fermata dei container"))
    
    return result

# Endpoint per listare i container gestiti da docker compose
@router.get("/compose/ps", response_model=Dict[str, Any])
async def docker_compose_ps(current_admin = Depends(get_current_admin)):
    """
    Lista i container gestiti da docker compose
    """
    result = compose_ps()
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nel recupero dei container"))
    
    return result

# Endpoint per ottenere lo stato specifico di virtual-dsm
@router.get("/virtual-dsm/status", response_model=Dict[str, Any])
async def get_virtual_dsm_status(current_admin = Depends(get_current_admin)):
    """
    Ottiene lo stato del container virtual-dsm
    """
    result = get_container_status("virtual-dsm")
    
    if not result["success"] and result.get("exists", True):
        raise HTTPException(status_code=404, detail="Container virtual-dsm non trovato")
    
    # Aggiungi informazioni specifiche per virtual-dsm
    if result.get("running", False):
        result["access_url"] = "http://localhost:5000"
        result["ready"] = True
    else:
        result["access_url"] = None
        result["ready"] = False
    
    return result

# Endpoint per ottenere la configurazione di Virtual DSM
@router.get("/virtual-dsm/config", response_model=Dict[str, str])
async def get_virtual_dsm_config(current_admin = Depends(get_current_admin)):
    """
    Ottiene la configurazione corrente di Virtual DSM dal docker-compose.yml
    """
    compose_file = "/opt/armnas/docker-compose.yml"
    
    if not os.path.exists(compose_file):
        raise HTTPException(status_code=404, detail="File docker-compose.yml non trovato")
    
    try:
        with open(compose_file, 'r') as f:
            content = f.read()
        
        # Estrae le variabili d'ambiente dalla configurazione
        config = {}
        
        # DISK_SIZE - supporta sia formato vecchio che array
        match = re.search(r'-\s*DISK_SIZE=([^\n]+)', content)
        if not match:
            match = re.search(r'DISK_SIZE:\s*"?([^"\n]+)"?', content)
        config["disk_size"] = match.group(1).strip() if match else "256G"
        
        # HOST_SERIAL
        match = re.search(r'-\s*HOST_SERIAL=([^\n]+)', content)
        if not match:
            match = re.search(r'HOST_SERIAL:\s*"?([^"\n]+)"?', content)
        config["host_serial"] = match.group(1).strip() if match else ""
        
        # GUEST_SERIAL
        match = re.search(r'-\s*GUEST_SERIAL=([^\n]+)', content)
        if not match:
            match = re.search(r'GUEST_SERIAL:\s*"?([^"\n]+)"?', content)
        config["guest_serial"] = match.group(1).strip() if match else ""
        
        # VM_NET_MAC
        match = re.search(r'-\s*VM_NET_MAC=([^\n]+)', content)
        if not match:
            match = re.search(r'VM_NET_MAC:\s*"?([^"\n]+)"?', content)
        config["vm_net_mac"] = match.group(1).strip() if match else ""
        
        return config
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nella lettura della configurazione: {str(e)}")

# Endpoint per aggiornare la configurazione di Virtual DSM
@router.put("/virtual-dsm/config", response_model=Dict[str, str])
async def update_virtual_dsm_config(config: VirtualDSMConfig, current_admin = Depends(get_current_admin)):
    """
    Aggiorna la configurazione di Virtual DSM nel docker-compose.yml
    """
    compose_file = "/opt/armnas/docker-compose.yml"
    
    if not os.path.exists(compose_file):
        raise HTTPException(status_code=404, detail="File docker-compose.yml non trovato")
    
    # Valida il formato della dimensione (numero seguito da G, M, T, ecc.)
    if not re.match(r'^\d+[GMTPE]?$', config.disk_size):
        raise HTTPException(status_code=400, detail="Formato dimensione non valido. Usa formato come '256G', '512G', '1T', ecc.")
    
    # Valida il formato MAC address se fornito
    if config.vm_net_mac and not re.match(r'^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$', config.vm_net_mac):
        raise HTTPException(status_code=400, detail="Formato MAC address non valido. Usa formato come '00:11:22:33:44:55' o '00-11-22-33-44-55'")
    
    try:
        # Leggi il file
        with open(compose_file, 'r') as f:
            content = f.read()
        
        # Funzione helper per aggiornare/aggiungere una variabile d'ambiente
        def update_env_var(content, var_name, var_value):
            # Usa sintassi array per environment (formato: - VAR=value)
            # Pattern per trovare la variabile in formato array
            pattern_array = rf'(\s+)-\s*{var_name}=.*\n'
            # Pattern per trovare la variabile in formato vecchio
            pattern_old = rf'(\s+){var_name}:\s*["\']?[^"\']*["\']?\s*\n'
            
            if var_value:
                replacement = f'      - {var_name}={var_value}\n'
            else:
                replacement = ""
            
            # Rimuovi formato vecchio se esiste
            if re.search(pattern_old, content):
                content = re.sub(pattern_old, '', content)
            
            # PRIMA: Assicurati che environment: abbia sempre un newline dopo
            # Cerca environment: senza newline dopo (seguito da qualsiasi cosa)
            content = re.sub(r'(    environment:)([^\n])', r'\1\n\2', content)
            
            # Cerca se la variabile esiste già in formato array
            if re.search(pattern_array, content):
                if var_value:
                    # Sostituisci il valore esistente
                    content = re.sub(pattern_array, replacement, content)
                else:
                    # Rimuovi la riga se il valore è vuoto
                    content = re.sub(pattern_array, '', content)
            else:
                if var_value:
                    # Aggiungi la variabile nella sezione environment
                    env_pattern = r'(environment:\s*\n)'
                    if re.search(env_pattern, content):
                        # Trova l'ultima variabile d'ambiente in formato array
                        env_section_match = re.search(r'(environment:\s*\n)((\s+-\s+[A-Z_]+=.*\n)+)', content)
                        if env_section_match:
                            # Aggiungi dopo l'ultima variabile esistente
                            insert_pos = env_section_match.end()
                            content = content[:insert_pos] + replacement + content[insert_pos:]
                        else:
                            # Non ci sono altre variabili, aggiungi dopo environment:
                            content = re.sub(env_pattern, rf'\1{replacement}', content, count=1)
                    else:
                        # Crea la sezione environment
                        services_pattern = r'(virtual-dsm:\s*\n\s+image:\s+vdsm/virtual-dsm\s*\n)'
                        content = re.sub(services_pattern, rf'\1    environment:\n{replacement}', content)
            return content
        
        # Aggiorna tutte le variabili d'ambiente
        content = update_env_var(content, "DISK_SIZE", config.disk_size)
        content = update_env_var(content, "HOST_SERIAL", config.host_serial)
        content = update_env_var(content, "GUEST_SERIAL", config.guest_serial)
        content = update_env_var(content, "VM_NET_MAC", config.vm_net_mac)
        
        # Rimuovi righe vuote multiple nella sezione environment
        content = re.sub(r'(\n\s+environment:\s*\n)(\n)+', r'\1', content)
        
        # Assicura che il filesystem sia in modalità RW per scrivere il file
        # /opt/armnas dovrebbe essere sempre scrivibile grazie al bind mount,
        # ma verifichiamo comunque
        compose_dir = os.path.dirname(compose_file)
        if not is_filesystem_writable(compose_dir):
            # Prova a passare a RW se non siamo già in RW
            if not ensure_rw_mode():
                raise HTTPException(
                    status_code=500,
                    detail=f"Impossibile scrivere in {compose_dir}. Verifica che overlayfs sia in modalità RW o che /opt/armnas sia montato correttamente."
                )
            # Verifica di nuovo dopo il passaggio a RW
            if not is_filesystem_writable(compose_dir):
                raise HTTPException(
                    status_code=500,
                    detail=f"{compose_dir} non è scrivibile dopo il passaggio a RW. Verifica i permessi."
                )
        
        # Scrivi il file
        with open(compose_file, 'w') as f:
            f.write(content)
        
        message_parts = [f"Dimensione disco aggiornata a {config.disk_size}"]
        if config.host_serial:
            message_parts.append(f"HOST_SERIAL impostato")
        if config.guest_serial:
            message_parts.append(f"GUEST_SERIAL impostato")
        if config.vm_net_mac:
            message_parts.append(f"VM_NET_MAC impostato")
        
        return {
            "status": "success",
            "message": ". ".join(message_parts),
            "disk_size": config.disk_size,
            "host_serial": config.host_serial or "",
            "guest_serial": config.guest_serial or "",
            "vm_net_mac": config.vm_net_mac or ""
        }
    
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Errore nell'aggiornamento della configurazione: {str(e)}")

class DockerDataRootConfig(BaseModel):
    data_root: str
    migrate: bool = False

# Endpoint per ottenere la configurazione Docker data-root
@router.get("/data-root", response_model=Dict[str, Any])
async def get_docker_data_root_config(current_admin = Depends(get_current_admin)):
    """
    Ottiene la configurazione corrente del Docker data-root
    """
    result = get_docker_data_root()
    
    if not result["success"]:
        raise HTTPException(status_code=500, detail=result.get("error", "Errore nel recupero della configurazione"))
    
    return result

# Endpoint per configurare Docker data-root
@router.put("/data-root", response_model=Dict[str, Any])
async def set_docker_data_root(config: DockerDataRootConfig, current_admin = Depends(get_current_admin)):
    """
    Configura Docker per usare un data-root personalizzato
    
    Args:
        config: Configurazione con data_root e migrate
    """
    if not config.data_root:
        raise HTTPException(status_code=400, detail="data-root non specificato")
    
    # Ottieni il data-root corrente
    current_config = get_docker_data_root()
    if not current_config["success"]:
        raise HTTPException(status_code=500, detail="Impossibile leggere la configurazione corrente")
    
    current_data_root = current_config["data_root"]
    
    # Se è già configurato, non fare nulla
    if current_data_root == config.data_root:
        return {
            "success": True,
            "message": f"Docker è già configurato per usare {config.data_root}",
            "data_root": config.data_root
        }
    
    # Configura il nuovo data-root
    result = configure_docker_data_root(config.data_root)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result.get("error", "Errore nella configurazione"))
    
    # Se richiesta, migra i dati
    if config.migrate and current_data_root != "/var/lib/docker":
        migrate_result = migrate_docker_data(current_data_root, config.data_root)
        if not migrate_result["success"]:
            # La configurazione è già stata applicata, ma la migrazione è fallita
            return {
                "success": False,
                "error": migrate_result.get("error", "Errore durante la migrazione"),
                "data_root": config.data_root,
                "note": "La configurazione è stata applicata ma la migrazione è fallita. Riavvia Docker manualmente."
            }
        result["message"] += f" {migrate_result['message']}"
    else:
        # Riavvia Docker automaticamente per applicare le modifiche
        from ..utils.docker_utils import run_command
        restart_result = run_command(["systemctl", "restart", "docker"])
        if restart_result["success"]:
            result["message"] += " Docker riavviato automaticamente."
        else:
            result["message"] += " Riavvia Docker manualmente per applicare le modifiche."
    
    return result

