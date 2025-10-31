#!/usr/bin/env python3
"""
Server di esempio per la distribuzione degli aggiornamenti ArmNAS
Questo è un server Flask semplice che gestisce le richieste di aggiornamento
"""

from flask import Flask, jsonify, request, send_file, abort
import os
import json
import hashlib
from datetime import datetime
from pathlib import Path

app = Flask(__name__)

# Configurazione
UPDATE_DIR = Path("./updates")  # Directory contenente i pacchetti di aggiornamento
UPDATE_DIR.mkdir(exist_ok=True)

# Database semplice delle versioni (in produzione usare un vero database)
VERSIONS_DB = {
    "0.1.0": {
        "release_date": "2024-01-01T00:00:00",
        "changelog": ["Versione iniziale"],
        "critical": False
    },
    "0.2.0": {
        "release_date": "2024-01-15T00:00:00", 
        "changelog": [
            "Aggiunto sistema di aggiornamento automatico",
            "Migliorata interfaccia utente",
            "Correzioni di sicurezza"
        ],
        "critical": False
    },
    "0.2.1": {
        "release_date": "2024-01-20T00:00:00",
        "changelog": [
            "Correzione critica di sicurezza",
            "Risolti problemi di stabilità"
        ],
        "critical": True
    }
}

def get_latest_version():
    """Ottieni l'ultima versione disponibile"""
    versions = list(VERSIONS_DB.keys())
    versions.sort(key=lambda x: [int(i) for i in x.split('.')])
    return versions[-1] if versions else None

def version_compare(v1, v2):
    """Confronta due versioni (ritorna True se v2 > v1)"""
    v1_parts = [int(x) for x in v1.split('.')]
    v2_parts = [int(x) for x in v2.split('.')]
    
    # Pareggia le lunghezze
    max_len = max(len(v1_parts), len(v2_parts))
    v1_parts.extend([0] * (max_len - len(v1_parts)))
    v2_parts.extend([0] * (max_len - len(v2_parts)))
    
    return v2_parts > v1_parts

def get_file_info(version):
    """Ottieni informazioni sul file di aggiornamento"""
    filename = f"armnas_update_v{version}.run"
    filepath = UPDATE_DIR / filename
    info_filepath = UPDATE_DIR / f"{filename}.info"
    
    if not filepath.exists():
        return None
    
    # Leggi le informazioni se disponibili
    if info_filepath.exists():
        with open(info_filepath, 'r') as f:
            return json.load(f)
    
    # Altrimenti calcola le informazioni base
    stat = filepath.stat()
    checksum = calculate_checksum(filepath)
    
    return {
        "filename": filename,
        "version": version,
        "size": stat.st_size,
        "checksum": checksum,
        "created": datetime.fromtimestamp(stat.st_ctime).isoformat(),
        "download_url": f"{request.url_root}api/v1/download/{filename}"
    }

def calculate_checksum(filepath):
    """Calcola il checksum SHA256"""
    sha256_hash = hashlib.sha256()
    with open(filepath, "rb") as f:
        for chunk in iter(lambda: f.read(4096), b""):
            sha256_hash.update(chunk)
    return sha256_hash.hexdigest()

@app.route('/api/v1/check-update')
def check_update():
    """Controlla se ci sono aggiornamenti disponibili"""
    current_version = request.args.get('current_version', '0.0.0')
    
    latest_version = get_latest_version()
    if not latest_version:
        return jsonify({
            "update_available": False,
            "error": "Nessuna versione disponibile"
        })
    
    update_available = version_compare(current_version, latest_version)
    
    response = {
        "update_available": update_available,
        "current_version": current_version,
        "latest_version": latest_version
    }
    
    if update_available:
        version_info = VERSIONS_DB.get(latest_version, {})
        file_info = get_file_info(latest_version)
        
        if file_info:
            response.update({
                "changelog": version_info.get("changelog", []),
                "release_date": version_info.get("release_date"),
                "critical": version_info.get("critical", False),
                "download_url": file_info["download_url"],
                "file_size": file_info["size"],
                "checksum": file_info["checksum"]
            })
        else:
            response["error"] = "File di aggiornamento non trovato"
    
    return jsonify(response)

@app.route('/api/v1/versions')
def list_versions():
    """Lista tutte le versioni disponibili"""
    versions = []
    
    for version, info in VERSIONS_DB.items():
        file_info = get_file_info(version)
        version_data = {
            "version": version,
            "release_date": info.get("release_date"),
            "changelog": info.get("changelog", []),
            "critical": info.get("critical", False),
            "available": file_info is not None
        }
        
        if file_info:
            version_data.update({
                "download_url": file_info["download_url"],
                "file_size": file_info["size"],
                "checksum": file_info["checksum"]
            })
        
        versions.append(version_data)
    
    # Ordina per versione
    versions.sort(key=lambda x: [int(i) for i in x["version"].split('.')], reverse=True)
    
    return jsonify({"versions": versions})

@app.route('/api/v1/download/<filename>')
def download_file(filename):
    """Scarica un file di aggiornamento"""
    if not filename.endswith('.run'):
        abort(400, "Solo file .run sono supportati")
    
    filepath = UPDATE_DIR / filename
    if not filepath.exists():
        abort(404, "File non trovato")
    
    return send_file(filepath, as_attachment=True)

@app.route('/api/v1/upload', methods=['POST'])
def upload_update():
    """Upload di un nuovo pacchetto di aggiornamento (per amministratori)"""
    # In produzione, aggiungere autenticazione
    auth_token = request.headers.get('Authorization')
    if not auth_token or auth_token != 'Bearer admin-secret-token':
        abort(401, "Non autorizzato")
    
    if 'file' not in request.files:
        abort(400, "Nessun file fornito")
    
    file = request.files['file']
    if not file.filename.endswith('.run'):
        abort(400, "Solo file .run sono supportati")
    
    # Salva il file
    filepath = UPDATE_DIR / file.filename
    file.save(filepath)
    
    # Rendi eseguibile
    os.chmod(filepath, 0o755)
    
    return jsonify({
        "success": True,
        "message": "File caricato con successo",
        "filename": file.filename
    })

@app.route('/api/v1/status')
def server_status():
    """Stato del server di aggiornamenti"""
    files = list(UPDATE_DIR.glob("*.run"))
    
    return jsonify({
        "server": "ArmNAS Update Server",
        "version": "1.0.0",
        "status": "online",
        "available_updates": len(files),
        "latest_version": get_latest_version(),
        "update_directory": str(UPDATE_DIR.absolute())
    })

@app.route('/')
def index():
    """Pagina principale"""
    return """
    <h1>ArmNAS Update Server</h1>
    <p>Server per la distribuzione degli aggiornamenti ArmNAS</p>
    <h2>API Endpoints:</h2>
    <ul>
        <li><a href="/api/v1/status">GET /api/v1/status</a> - Stato del server</li>
        <li><a href="/api/v1/versions">GET /api/v1/versions</a> - Lista versioni</li>
        <li>GET /api/v1/check-update?current_version=X.X.X - Controlla aggiornamenti</li>
        <li>GET /api/v1/download/filename.run - Scarica aggiornamento</li>
        <li>POST /api/v1/upload - Upload aggiornamento (richiede auth)</li>
    </ul>
    """

if __name__ == '__main__':
    print("🚀 Avvio ArmNAS Update Server")
    print(f"📁 Directory aggiornamenti: {UPDATE_DIR.absolute()}")
    print(f"🌐 Server disponibile su: http://localhost:5000")
    print(f"📋 Versioni disponibili: {list(VERSIONS_DB.keys())}")
    
    app.run(host='0.0.0.0', port=5000, debug=True)