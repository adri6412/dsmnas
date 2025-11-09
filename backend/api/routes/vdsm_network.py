from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, Dict, Any
import os
import yaml
import subprocess
from ..auth import get_current_admin

router = APIRouter()

class MacvlanConfig(BaseModel):
    enabled: bool
    subnet: Optional[str] = "192.168.0.0/24"
    gateway: Optional[str] = "192.168.0.1"
    ip_range: Optional[str] = "192.168.0.100/28"
    parent_interface: Optional[str] = "eth0"
    container_ip: Optional[str] = "192.168.0.100"
    use_dhcp: bool = False

@router.post("/configure-network")
async def configure_vdsm_network(config: MacvlanConfig, current_admin = Depends(get_current_admin)):
    """
    Configura rete macvlan per Virtual DSM con IP separato
    Preserva tutte le configurazioni utente esistenti (DISK_SIZE, SERIAL, etc.)
    """
    compose_file = "/opt/armnas/docker-compose.yml"
    
    # Verifica che il file esista
    if not os.path.exists(compose_file):
        raise HTTPException(status_code=404, detail="docker-compose.yml non trovato")
    
    try:
        # Leggi configurazione esistente
        with open(compose_file, 'r') as f:
            compose_data = yaml.safe_load(f)
        
        if not compose_data or 'services' not in compose_data:
            raise HTTPException(status_code=400, detail="docker-compose.yml non valido")
        
        service = compose_data['services'].get('virtual-dsm')
        if not service:
            raise HTTPException(status_code=404, detail="Servizio virtual-dsm non trovato")
        
        if config.enabled:
            # Abilita macvlan
            
            # 1. Crea rete macvlan se non esiste
            network_name = "vdsm"
            network_exists = subprocess.run(
                ["docker", "network", "inspect", network_name],
                capture_output=True
            ).returncode == 0
            
            if not network_exists:
                # Crea rete macvlan con modalità bridge esplicita
                # Soluzione da: https://github.com/docker/compose/issues/11716
                cmd = [
                    "docker", "network", "create", "-d", "macvlan",
                    "-o", "macvlan_mode=bridge",  # Modalità bridge esplicita
                    "-o", f"parent={config.parent_interface}",
                    "--subnet", config.subnet,
                    "--gateway", config.gateway,
                    f"--ip-range={config.container_ip}/32",  # IP singolo /32
                    network_name
                ]
                
                result = subprocess.run(cmd, capture_output=True, text=True)
                if result.returncode != 0:
                    raise HTTPException(status_code=500, detail=f"Errore creazione rete: {result.stderr}")
            
            # 2. Configura servizio con rete macvlan
            # Rimuovi mappatura porte (non necessaria con macvlan)
            if 'ports' in service:
                del service['ports']
            
            # Container Docker SEMPRE con IP statico su macvlan
            # Importante: usa dizionario, non lista
            service['networks'] = {}
            service['networks'][network_name] = {
                'ipv4_address': config.container_ip
            }
            
            # DHCP=Y è SOLO per la VM DSM, non per il container
            if config.use_dhcp:
                # Modalità DHCP: VM DSM ottiene IP dal router (non il container!)
                if 'environment' not in service:
                    service['environment'] = []
                
                # Aggiungi DHCP=Y per la VM
                env_list = service['environment']
                if isinstance(env_list, list):
                    # Rimuovi vecchio DHCP se presente
                    env_list = [e for e in env_list if not e.startswith('DHCP=')]
                    env_list.append('DHCP=Y')
                    service['environment'] = env_list
                
                # Aggiungi devices necessari per DHCP della VM
                if 'devices' not in service:
                    service['devices'] = []
                if '/dev/vhost-net' not in service['devices']:
                    service['devices'].append('/dev/vhost-net')
                
                # Aggiungi device_cgroup_rules
                service['device_cgroup_rules'] = ['c *:* rwm']
            else:
                # Rimuovi DHCP se era abilitato prima
                if 'environment' in service and isinstance(service['environment'], list):
                    service['environment'] = [e for e in service['environment'] if not e.startswith('DHCP=')]
                
                # Rimuovi device_cgroup_rules se presente
                if 'device_cgroup_rules' in service:
                    del service['device_cgroup_rules']
            
            # Aggiungi definizione rete esterna
            if 'networks' not in compose_data:
                compose_data['networks'] = {}
            compose_data['networks'][network_name] = {'external': True}
            
        else:
            # Disabilita macvlan - torna a bridge
            
            # Rimuovi configurazione rete
            if 'networks' in service:
                del service['networks']
            
            # Rimuovi DHCP se presente
            if 'environment' in service and isinstance(service['environment'], list):
                service['environment'] = [e for e in service['environment'] if not e.startswith('DHCP=')]
            
            # Rimuovi device_cgroup_rules se presente
            if 'device_cgroup_rules' in service:
                del service['device_cgroup_rules']
            
            # Ripristina porta 5000
            service['ports'] = ['5000:5000']
            
            # Rimuovi definizione networks dal compose
            if 'networks' in compose_data:
                compose_data['networks'].pop('vdsm', None)
                if not compose_data['networks']:
                    del compose_data['networks']
        
        # Salva configurazione aggiornata
        with open(compose_file, 'w') as f:
            yaml.dump(compose_data, f, default_flow_style=False, sort_keys=False, allow_unicode=True, width=1000)
        
        return {
            "success": True,
            "message": "Configurazione rete aggiornata. Ricrea container: docker compose down && docker compose up -d",
            "network_type": "macvlan" if config.enabled else "bridge",
            "dhcp_enabled": config.use_dhcp if config.enabled else False
        }
        
    except yaml.YAMLError as e:
        import traceback
        error_detail = f"Errore parsing YAML: {str(e)}\n{traceback.format_exc()}"
        print(error_detail)  # Log nel backend
        raise HTTPException(status_code=400, detail=error_detail)
    except Exception as e:
        import traceback
        error_detail = f"Errore: {str(e)}\n{traceback.format_exc()}"
        print(error_detail)  # Log nel backend
        raise HTTPException(status_code=500, detail=error_detail)

@router.get("/network-config")
async def get_vdsm_network_config(current_admin = Depends(get_current_admin)):
    """
    Ottiene la configurazione rete corrente di Virtual DSM
    """
    compose_file = "/opt/armnas/docker-compose.yml"
    
    if not os.path.exists(compose_file):
        return {
            "success": False,
            "error": "docker-compose.yml non trovato"
        }
    
    try:
        with open(compose_file, 'r') as f:
            compose_data = yaml.safe_load(f)
        
        service = compose_data.get('services', {}).get('virtual-dsm', {})
        
        # Determina configurazione corrente
        has_networks = 'networks' in service
        has_dhcp = False
        network_type = "bridge"
        
        if 'environment' in service:
            env_list = service['environment']
            if isinstance(env_list, list):
                has_dhcp = any('DHCP=Y' in str(e) for e in env_list)
        
        if has_networks:
            network_type = "macvlan"
        
        return {
            "success": True,
            "enabled": has_networks,
            "network_type": network_type,
            "use_dhcp": has_dhcp,
            "has_ports": 'ports' in service
        }
        
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

