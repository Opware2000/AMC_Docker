#!/bin/bash
# ============================================================
# Entrypoint AMC Docker — Mode VNC (contournement fond noir XQuartz)
# - Démarre Xvfb (framebuffer virtuel :99)
# - Démarre x11vnc sur le port 5900
# - Installe la classe nQCM dans TEXMFLOCAL si présente
# - Lance AMC sur l'affichage virtuel
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== AMC Docker — Démarrage (mode VNC) ===${NC}"

# ── 0. Démarrage Xvfb + x11vnc ──────────────────────────────
VNC_DISPLAY=:99
VNC_PORT=5900
VNC_GEOMETRY="${VNC_GEOMETRY:-2560x1600}"

echo -e "${GREEN}→ Démarrage Xvfb ($VNC_GEOMETRY)...${NC}"
rm -f /tmp/.X99-lock /tmp/.X11-unix/X99 2>/dev/null || true
Xvfb "$VNC_DISPLAY" -screen 0 "${VNC_GEOMETRY}x24" -ac &
XVFB_PID=$!
sleep 1

export DISPLAY="$VNC_DISPLAY"

# Gestionnaire de fenêtres léger (nécessaire pour GTK)
fluxbox &>/dev/null &

echo -e "${GREEN}→ Démarrage x11vnc (port 5900)...${NC}"
x11vnc -display "$VNC_DISPLAY" -forever -nopw -quiet \
       -rfbport 5900 -bg -o /tmp/x11vnc.log

echo -e "${GREEN}→ Démarrage noVNC (port 6080)...${NC}"
websockify --web /usr/share/novnc 6080 localhost:5900 &>/tmp/novnc.log &

echo -e "${GREEN}✓ Interface disponible sur : http://localhost:6080/vnc.html${NC}"
echo ""

# Nettoyage au exit
trap "kill $XVFB_PID 2>/dev/null; true" EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== AMC Docker — Démarrage ===${NC}"

# ── 1. Installation de la classe LaTeX nQCM ─────────────────
NQCM_SRC="/nqcm"
TEXMFLOCAL=$(kpsewhich -var-value TEXMFLOCAL 2>/dev/null || echo "/usr/share/texmf")
NQCM_DEST="$TEXMFLOCAL/tex/latex/nQcm"

if [ -d "$NQCM_SRC" ] && [ "$(ls -A $NQCM_SRC 2>/dev/null)" ]; then
    echo -e "${GREEN}→ Installation de la classe nQCM dans $NQCM_DEST${NC}"
    mkdir -p "$NQCM_DEST"
    rsync -a --checksum "$NQCM_SRC/" "$NQCM_DEST/"
    echo "→ Mise à jour de la base TeX (mktexlsr)..."
    mktexlsr 2>/dev/null || texhash 2>/dev/null || true
    echo -e "${GREEN}✓ Classe nQCM installée${NC}"
else
    echo -e "${YELLOW}⚠ Répertoire nQCM non monté ou vide ($NQCM_SRC)${NC}"
    echo "  Vérifiez le volume dans docker-compose.yml"
fi

# ── 2. Configuration du clavier Mac français ─────────────────
if command -v setxkbmap &>/dev/null; then
    setxkbmap -model apple -layout fr -variant mac -display "$DISPLAY" 2>/dev/null || true
fi

# ── 3. Configuration GTK ─────────────────────────────────────
mkdir -p /root/.config/gtk-3.0
cat > /root/.config/gtk-3.0/settings.ini << 'GTK_EOF'
[Settings]
gtk-double-click-time=400
gtk-double-click-distance=8
gtk-dnd-drag-threshold=12
gtk-primary-button-warps-slider=true
gtk-overlay-scrolling=false
GTK_EOF

mkdir -p /root/.config/gtk-2.0
cat > /root/.config/gtk-2.0/gtkrc << 'GTK2_EOF'
gtk-double-click-time = 400
gtk-double-click-distance = 8
gtk-dnd-drag-threshold = 12
GTK2_EOF

# ── 4. Lancement d'AMC ──────────────────────────────────────
echo -e "${GREEN}→ Lancement de Auto-Multiple-Choice...${NC}"
echo ""
exec "$@"
