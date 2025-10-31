from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Dict, Optional, Any
from ..auth import get_current_admin
from ..utils.zfs_utils import (
    get_zfs_pools, 
    get_zfs_datasets, 
    get_available_disks,
    create_zfs_pool,
    destroy_zfs_pool,
    create_zfs_dataset,
    destroy_zfs_dataset,
    get_zfs_pool_status,
    get_zfs_pool_properties,
    get_zfs_dataset_properties
)

router = APIRouter()

# Modelli Pydantic
class ZFSPoolCreate(BaseModel):
    name: str
    raid_type: str  # mirror, raidz, raidz2, raidz3, stripe
    disks: List[str]
    mount_point: Optional[str] = None

class ZFSDatasetCreate(BaseModel):
    pool_name: str
    dataset_name: str
    mount_point: Optional[str] = None
    quota: Optional[str] = None
    compression: Optional[str] = None

class ZFSPoolDestroy(BaseModel):
    name: str
    force: bool = False

class ZFSDatasetDestroy(BaseModel):
    name: str
    recursive: bool = False
    force: bool = False

# Endpoint per ottenere l'elenco dei pool ZFS
@router.get("/pools", response_model=List[Dict[str, Any]])
async def list_zfs_pools(current_admin = Depends(get_current_admin)):
    """
    Ottiene l'elenco dei pool ZFS
    """
    return get_zfs_pools()

# Endpoint per ottenere l'elenco dei dataset ZFS
@router.get("/datasets", response_model=List[Dict[str, Any]])
async def list_zfs_datasets(current_admin = Depends(get_current_admin)):
    """
    Ottiene l'elenco dei dataset ZFS
    """
    return get_zfs_datasets()

# Endpoint per ottenere l'elenco dei dischi disponibili per ZFS
@router.get("/available-disks", response_model=List[Dict[str, Any]])
async def list_available_disks(current_admin = Depends(get_current_admin)):
    """
    Ottiene l'elenco dei dischi disponibili per la creazione di pool ZFS
    """
    return get_available_disks()

# Endpoint per creare un nuovo pool ZFS
@router.post("/pools", response_model=Dict[str, Any])
async def create_pool(pool_data: ZFSPoolCreate, current_admin = Depends(get_current_admin)):
    """
    Crea un nuovo pool ZFS
    """
    result = create_zfs_pool(
        pool_data.name,
        pool_data.raid_type,
        pool_data.disks,
        pool_data.mount_point
    )
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    
    return result

# Endpoint per distruggere un pool ZFS
@router.delete("/pools", response_model=Dict[str, Any])
async def destroy_pool(pool_data: ZFSPoolDestroy, current_admin = Depends(get_current_admin)):
    """
    Distrugge un pool ZFS
    """
    result = destroy_zfs_pool(pool_data.name, pool_data.force)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    
    return result

# Endpoint per creare un nuovo dataset ZFS
@router.post("/datasets", response_model=Dict[str, Any])
async def create_dataset(dataset_data: ZFSDatasetCreate, current_admin = Depends(get_current_admin)):
    """
    Crea un nuovo dataset ZFS
    """
    result = create_zfs_dataset(
        dataset_data.pool_name,
        dataset_data.dataset_name,
        dataset_data.mount_point,
        dataset_data.quota,
        dataset_data.compression
    )
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    
    return result

# Endpoint per distruggere un dataset ZFS
@router.delete("/datasets", response_model=Dict[str, Any])
async def destroy_dataset(dataset_data: ZFSDatasetDestroy, current_admin = Depends(get_current_admin)):
    """
    Distrugge un dataset ZFS
    """
    result = destroy_zfs_dataset(dataset_data.name, dataset_data.recursive, dataset_data.force)
    
    if not result["success"]:
        raise HTTPException(status_code=400, detail=result["error"])
    
    return result

# Endpoint per ottenere lo stato di un pool ZFS
@router.get("/pools/{name}/status", response_model=Dict[str, Any])
async def get_pool_status(name: str, current_admin = Depends(get_current_admin)):
    """
    Ottiene lo stato dettagliato di un pool ZFS
    """
    result = get_zfs_pool_status(name)
    
    if not result["success"]:
        raise HTTPException(status_code=404, detail=f"Pool ZFS '{name}' non trovato")
    
    return result

# Endpoint per ottenere le proprietà di un pool ZFS
@router.get("/pools/{name}/properties", response_model=Dict[str, Any])
async def get_pool_properties(name: str, current_admin = Depends(get_current_admin)):
    """
    Ottiene le proprietà di un pool ZFS
    """
    result = get_zfs_pool_properties(name)
    
    if not result["success"]:
        raise HTTPException(status_code=404, detail=f"Pool ZFS '{name}' non trovato")
    
    return result

# Endpoint per ottenere le proprietà di un dataset ZFS
@router.get("/datasets/{name}/properties", response_model=Dict[str, Any])
async def get_dataset_properties(name: str, current_admin = Depends(get_current_admin)):
    """
    Ottiene le proprietà di un dataset ZFS
    """
    result = get_zfs_dataset_properties(name)
    
    if not result["success"]:
        raise HTTPException(status_code=404, detail=f"Dataset ZFS '{name}' non trovato")
    
    return result