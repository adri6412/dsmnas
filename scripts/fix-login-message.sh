#!/bin/bash
# Script veloce per rimuovere il messaggio "Installazione già completata" dal login
# Uso: sudo bash fix-login-message.sh

# Colori
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Verifica root
if [ "$EUID" -ne 0 ]; then
    echo "Questo script deve essere eseguito come root (usa sudo)"
    exit 1
fi

info "=== Rimozione Messaggio Login ==="
echo ""

# Backup .profile
if [ -f /root/.profile ] && [ ! -f /root/.profile.bak ]; then
    cp /root/.profile /root/.profile.bak
    info "✓ Backup creato: /root/.profile.bak"
fi

# Pulisci .profile
if [ -f /root/.profile ]; then
    info "Pulizia /root/.profile..."
    
    # Rimuovi tutte le righe problematiche
    sed -i '/installer_dsm\.sh/d' /root/.profile 2>/dev/null || true
    sed -i '/FLAG_FILE/d' /root/.profile 2>/dev/null || true
    sed -i '/ARM NAS - Installazione Automatica/d' /root/.profile 2>/dev/null || true
    sed -i '/INSTALLER=/d' /root/.profile 2>/dev/null || true
    sed -i '/Installazione già completata/d' /root/.profile 2>/dev/null || true
    sed -i '/già completata/d' /root/.profile 2>/dev/null || true
    sed -i '/installer-completed/d' /root/.profile 2>/dev/null || true
    sed -i '/\/var\/lib\/armnas/d' /root/.profile 2>/dev/null || true
    sed -i '/rieseguire.*rm.*FLAG/d' /root/.profile 2>/dev/null || true
    sed -i '/Per rieseguire/d' /root/.profile 2>/dev/null || true
    
    # Rimuovi blocchi if-fi relativi al flag file
    sed -i '/if \[ -f "\$FLAG_FILE" \]/,/^fi$/d' /root/.profile 2>/dev/null || true
    sed -i '/if \[ -f.*installer-completed/,/^fi$/d' /root/.profile 2>/dev/null || true
    
    info "✓ Messaggi rimossi da .profile"
fi

# Verifica se .profile è quasi vuoto e ricrealo
if [ $(wc -l < /root/.profile 2>/dev/null || echo 0) -lt 5 ]; then
    info "Ricreazione .profile standard..."
    cat > /root/.profile << 'EOF'
# ~/.profile: executed by Bourne-compatible login shells.

if [ "$BASH" ]; then
  if [ -f ~/.bashrc ]; then
    . ~/.bashrc
  fi
fi

mesg n 2> /dev/null || true
EOF
    info "✓ .profile ricreato"
fi

# Verifica contenuto finale
echo ""
info "Contenuto /root/.profile:"
cat /root/.profile
echo ""

info "✅ Fatto! Il messaggio non apparirà più al prossimo login."
info ""
info "Per applicare subito, ricarica il profilo:"
info "  source /root/.profile"
info ""
info "Oppure esci e rientra:"
info "  exit"

