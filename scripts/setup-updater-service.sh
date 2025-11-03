#!/bin/bash
# Script per configurare il servizio updater separato

INSTALL_DIR="/opt/armnas"
BACKEND_DIR="$INSTALL_DIR/backend"

echo "🔧 Configurazione ArmNAS Update Service..."

# Crea il servizio systemd per l'updater
cat > /etc/systemd/system/armnas-updater.service << EOF
[Unit]
Description=ArmNAS Update Service (Separate)
After=network.target
PartOf=armnas-backend.service

[Service]
User=root
WorkingDirectory=$BACKEND_DIR
ExecStart=$BACKEND_DIR/venv/bin/python3 $BACKEND_DIR/updater_service.py
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

# Ricarica systemd
systemctl daemon-reload

# Abilita e avvia il servizio
systemctl enable armnas-updater.service
systemctl start armnas-updater.service

# Verifica stato
sleep 2
if systemctl is-active --quiet armnas-updater.service; then
    echo "✅ ArmNAS Update Service avviato correttamente"
    systemctl status armnas-updater.service --no-pager -l
else
    echo "❌ Errore nell'avvio del servizio"
    journalctl -u armnas-updater.service -n 20 --no-pager
    exit 1
fi

echo ""
echo "✅ Setup completato!"
echo "   - Servizio: armnas-updater.service"
echo "   - Porta: 8001"
echo "   - Log: journalctl -u armnas-updater -f"

