import subprocess
import json
import os
from typing import List, Dict, Optional, Any
from .overlayfs import ensure_rw_mode, is_filesystem_writable

def run_command(command: List[str], cwd: Optional[str] = None) -> Dict[str, Any]:
    """
    Esegue un comando e restituisce l'output come dizionario
    """
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            cwd=cwd
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

def is_docker_installed() -> bool:
    """
    Verifica se Docker è installato sul sistema
    """
    result = run_command(["which", "docker"])
    return result["success"]

def get_container_status(container_name: str) -> Dict[str, Any]:
    """
    Ottiene lo stato di un container Docker
    """
    cmd_result = run_command(["docker", "inspect", "--format", "{{json .}}", container_name])
    
    if not cmd_result["success"]:
        return {
            "success": False,
            "exists": False,
            "running": False,
            "error": cmd_result["error"]
        }
    
    try:
        container_info = json.loads(cmd_result["output"])
        
        # Estrai il MAC address dalla rete del container
        mac_address = None
        networks = container_info.get("NetworkSettings", {}).get("Networks", {})
        if networks:
            # Prendi il MAC address dalla prima rete disponibile
            first_network = next(iter(networks.values()), {})
            mac_address = first_network.get("MacAddress", None)
        
        return {
            "success": True,
            "exists": True,
            "running": container_info.get("State", {}).get("Running", False),
            "status": container_info.get("State", {}).get("Status", "unknown"),
            "started_at": container_info.get("State", {}).get("StartedAt", ""),
            "image": container_info.get("Config", {}).get("Image", ""),
            "ports": container_info.get("NetworkSettings", {}).get("Ports", {}),
            "mac_address": mac_address
        }
    except json.JSONDecodeError:
        return {
            "success": False,
            "exists": False,
            "running": False,
            "error": "Errore nel parsing delle informazioni del container"
        }

def start_container(container_name: str, working_dir: str = "/opt/armnas") -> Dict[str, Any]:
    """
    Avvia un container Docker usando docker compose up -d.
    Docker Compose gestisce automaticamente la creazione e l'avvio del container.
    """
    # Usa docker compose per creare e avviare il container
    # Compose gestisce tutto: se non esiste lo crea, se esiste lo avvia
    if check_compose_available():
        # Prova prima con 'docker compose'
        result = run_command(["docker", "compose", "up", "-d"], cwd=working_dir)
        if not result["success"]:
            # Prova con 'docker-compose'
            result = run_command(["docker-compose", "up", "-d"], cwd=working_dir)
    else:
        result = run_command(["docker-compose", "up", "-d"], cwd=working_dir)
    
    if result["success"]:
        return {
            "success": True,
            "message": f"Container '{container_name}' avviato con successo"
        }
    else:
        return {
            "success": False,
            "error": result.get("error", "Errore sconosciuto nell'avvio del container")
        }

def stop_container(container_name: str) -> Dict[str, Any]:
    """
    Ferma un container Docker
    """
    result = run_command(["docker", "stop", container_name])
    
    if result["success"]:
        return {
            "success": True,
            "message": f"Container '{container_name}' fermato con successo"
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def restart_container(container_name: str) -> Dict[str, Any]:
    """
    Riavvia un container Docker
    """
    result = run_command(["docker", "restart", container_name])
    
    if result["success"]:
        return {
            "success": True,
            "message": f"Container '{container_name}' riavviato con successo"
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def get_container_logs(container_name: str, tail: int = 100) -> Dict[str, Any]:
    """
    Ottiene i log di un container Docker
    """
    result = run_command(["docker", "logs", "--tail", str(tail), container_name])
    
    if result["success"]:
        return {
            "success": True,
            "logs": result["output"].split('\n')
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def check_compose_available() -> bool:
    """
    Verifica se docker compose è disponibile
    """
    # Prova prima con 'docker compose'
    result = run_command(["docker", "compose", "version"])
    if result["success"]:
        return True
    
    # Prova poi con 'docker-compose'
    result = run_command(["docker-compose", "--version"])
    return result["success"]

def compose_up(working_dir: str = "/opt/armnas") -> Dict[str, Any]:
    """
    Avvia i container con docker compose
    """
    if check_compose_available():
        # Prova prima con 'docker compose'
        result = run_command(["docker", "compose", "up", "-d"], cwd=working_dir)
        if not result["success"]:
            # Prova con 'docker-compose'
            result = run_command(["docker-compose", "up", "-d"], cwd=working_dir)
    else:
        result = run_command(["docker-compose", "up", "-d"], cwd=working_dir)
    
    if result["success"]:
        return {
            "success": True,
            "message": "Container avviati con successo"
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def compose_down(working_dir: str = "/opt/armnas") -> Dict[str, Any]:
    """
    Ferma i container con docker compose
    """
    if check_compose_available():
        # Prova prima con 'docker compose'
        result = run_command(["docker", "compose", "down"], cwd=working_dir)
        if not result["success"]:
            # Prova con 'docker-compose'
            result = run_command(["docker-compose", "down"], cwd=working_dir)
    else:
        result = run_command(["docker-compose", "down"], cwd=working_dir)
    
    if result["success"]:
        return {
            "success": True,
            "message": "Container fermati con successo"
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def compose_ps() -> Dict[str, Any]:
    """
    Lista i container gestiti da docker compose
    """
    # Ottieni la lista dei container in formato JSON
    if check_compose_available():
        # Prova prima con 'docker compose'
        result = run_command(["docker", "compose", "ps", "--format", "json"])
        if not result["success"]:
            # Prova con 'docker-compose'
            result = run_command(["docker-compose", "ps", "--format", "json"])
    else:
        result = run_command(["docker-compose", "ps", "--format", "json"])
    
    if not result["success"]:
        return {
            "success": False,
            "error": result["error"]
        }
    
    try:
        # Parse ogni riga come JSON separato
        containers = []
        for line in result["output"].splitlines():
            if line.strip():
                containers.append(json.loads(line))
        
        return {
            "success": True,
            "containers": containers
        }
    except json.JSONDecodeError:
        return {
            "success": False,
            "error": "Errore nel parsing dei container"
        }

def is_kvm_available() -> bool:
    """
    Verifica se KVM è disponibile sul sistema
    """
    result = run_command(["ls", "/dev/kvm"])
    return result["success"]

def get_docker_version() -> Dict[str, Any]:
    """
    Ottiene la versione di Docker installata
    """
    result = run_command(["docker", "--version"])
    
    if result["success"]:
        return {
            "success": True,
            "version": result["output"]
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def get_docker_compose_version() -> Dict[str, Any]:
    """
    Ottiene la versione di Docker Compose installata
    """
    if check_compose_available():
        result = run_command(["docker", "compose", "version"])
        if result["success"]:
            return {
                "success": True,
                "version": result["output"]
            }
    
    result = run_command(["docker-compose", "--version"])
    
    if result["success"]:
        return {
            "success": True,
            "version": result["output"]
        }
    else:
        return {
            "success": False,
            "error": result["error"]
        }

def get_docker_data_root() -> Dict[str, Any]:
    """
    Ottiene il data-root corrente di Docker
    """
    try:
        # Prova a leggere da daemon.json
        daemon_json_path = "/etc/docker/daemon.json"
        if os.path.exists(daemon_json_path):
            with open(daemon_json_path, 'r') as f:
                daemon_config = json.load(f)
                if "data-root" in daemon_config:
                    return {
                        "success": True,
                        "data_root": daemon_config["data-root"],
                        "source": "daemon.json"
                    }
        
        # Se non trovato, usa il default
        return {
            "success": True,
            "data_root": "/var/lib/docker",
            "source": "default"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

def configure_docker_data_root(data_root: str) -> Dict[str, Any]:
    """
    Configura Docker per usare un data-root personalizzato
    """
    if not data_root:
        return {
            "success": False,
            "error": "data-root non specificato"
        }
    
    # Verifica che la directory di destinazione esista o possa essere creata
    if not os.path.exists(data_root):
        try:
            os.makedirs(data_root, mode=0o755, exist_ok=True)
        except Exception as e:
            return {
                "success": False,
                "error": f"Impossibile creare la directory {data_root}: {str(e)}"
            }
    
    # Verifica che la directory sia scrivibile
    if not os.access(data_root, os.W_OK):
        return {
            "success": False,
            "error": f"La directory {data_root} non è scrivibile"
        }
    
    try:
        # Assicura che il filesystem sia in modalità RW per scrivere in /etc/docker
        if not ensure_rw_mode():
            return {
                "success": False,
                "error": "Impossibile passare a modalità RW. Il filesystem potrebbe essere in sola lettura."
            }
        
        # Verifica che /etc/docker sia scrivibile
        etc_docker = "/etc/docker"
        if not os.path.exists(etc_docker):
            os.makedirs(etc_docker, mode=0o755, exist_ok=True)
        
        if not is_filesystem_writable(etc_docker):
            return {
                "success": False,
                "error": "/etc/docker non è scrivibile. Verifica che overlayfs sia in modalità RW."
            }
        
        # Leggi la configurazione esistente o crea una nuova
        daemon_json_path = "/etc/docker/daemon.json"
        daemon_config = {}
        
        if os.path.exists(daemon_json_path):
            with open(daemon_json_path, 'r') as f:
                daemon_config = json.load(f)
        
        # Aggiorna o aggiungi data-root
        daemon_config["data-root"] = data_root
        
        # Backup del file esistente
        if os.path.exists(daemon_json_path):
            backup_path = f"{daemon_json_path}.bak"
            with open(daemon_json_path, 'r') as f_in:
                with open(backup_path, 'w') as f_out:
                    f_out.write(f_in.read())
        
        # Scrivi la nuova configurazione
        with open(daemon_json_path, 'w') as f:
            json.dump(daemon_config, f, indent=2)
        
        return {
            "success": True,
            "message": f"Docker data-root configurato su {data_root}",
            "data_root": data_root
        }
    except Exception as e:
        return {
            "success": False,
            "error": f"Errore nella configurazione: {str(e)}"
        }

def migrate_docker_data(old_data_root: str, new_data_root: str) -> Dict[str, Any]:
    """
    Migra i dati Docker da una directory all'altra
    """
    try:
        # Ferma Docker
        run_command(["systemctl", "stop", "docker"])
        
        # Se la nuova directory non esiste, creala
        if not os.path.exists(new_data_root):
            os.makedirs(new_data_root, mode=0o755)
        
        # Se la vecchia directory esiste e ha contenuti, copiali
        if os.path.exists(old_data_root) and os.listdir(old_data_root):
            result = run_command(["rsync", "-a", f"{old_data_root}/", f"{new_data_root}/"])
            if not result["success"]:
                # Riavvia Docker in caso di errore
                run_command(["systemctl", "start", "docker"])
                return {
                    "success": False,
                    "error": f"Errore durante la migrazione: {result['error']}"
                }
        
        # Riavvia Docker
        result = run_command(["systemctl", "start", "docker"])
        if not result["success"]:
            return {
                "success": False,
                "error": f"Errore durante il riavvio di Docker: {result['error']}"
            }
        
        return {
            "success": True,
            "message": f"Dati Docker migrati da {old_data_root} a {new_data_root}"
        }
    except Exception as e:
        # Riavvia Docker in caso di errore
        run_command(["systemctl", "start", "docker"])
        return {
            "success": False,
            "error": f"Errore durante la migrazione: {str(e)}"
        }

