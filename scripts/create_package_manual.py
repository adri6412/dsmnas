#!/usr/bin/env python3
"""
Script per creare manualmente il pacchetto di aggiornamento
"""

import sys
import os
from pathlib import Path

# Aggiungi il percorso del server-update
sys.path.insert(0, str(Path(__file__).parent / "server-update"))

try:
    from create_update_package_fixed import UpdatePackageBuilder
    
    print("🚀 Creazione pacchetto ArmNAS v0.2.2...")
    
    # Crea il builder
    builder = UpdatePackageBuilder("0.2.2", "./server-update/updates")
    
    # Crea il pacchetto
    package_file = builder.create_package(
        source_dir=".",
        changelog="Fix frontend update process and restore missing Updates menu item",
        critical=False
    )
    
    if package_file:
        print(f"\n🎉 Pacchetto creato con successo!")
        print(f"📁 File: {package_file}")
        print(f"📋 Info: {package_file}.info")
        print(f"\n💡 Per installare: sudo bash {package_file}")
    else:
        print("❌ Errore nella creazione del pacchetto")
        
except Exception as e:
    print(f"❌ Errore: {e}")
    import traceback
    traceback.print_exc()