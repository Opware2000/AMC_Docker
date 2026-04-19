#!/bin/bash
# ============================================================
# Entrypoint AMC Docker — Mode Xpra (fenêtre native Mac)
# - Démarre xpra en mode TCP sur le port 14500
# - Installe la classe nQCM dans TEXMFLOCAL si présente
# - Lance AMC via xpra ; le client Mac se connecte avec :
#     xpra attach tcp://localhost:14500/
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}=== AMC Docker — Démarrage (mode Xpra) ===${NC}"

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

# ── 2. Configuration GTK ─────────────────────────────────────
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

# Favoris GTK (visibles dans la barre latérale des dialogues Ouvrir/Enregistrer)
cat > /root/.config/gtk-3.0/bookmarks << 'BOOKMARKS_EOF'
file:///amc/controles Contrôles
file:///amc/scan SCAN
BOOKMARKS_EOF

# ── 3. Symlink projets AMC ───────────────────────────────────
ln -sfn /amc/controles /root/MC-Projects

# ── 4. Démarrage Xpra ───────────────────────────────────────
XPRA_DISPLAY=:10
XPRA_PORT=14500
AMC_CMD="${*:-auto-multiple-choice gui}"

rm -f "/tmp/.X${XPRA_DISPLAY#:}-lock" "/tmp/.X11-unix/X${XPRA_DISPLAY#:}" 2>/dev/null || true

echo -e "${GREEN}→ Démarrage xpra (port $XPRA_PORT)...${NC}"
echo -e "${YELLOW}  Sur Mac : xpra attach tcp://localhost:$XPRA_PORT/${NC}"
echo ""

# setxkbmap sera appelé par xpra via env DISPLAY une fois qu'il est prêt
export XPRA_KEYBOARD_LAYOUT="fr"
export XPRA_KEYBOARD_MODEL="apple"

exec xpra start "$XPRA_DISPLAY" \
    --bind-tcp=0.0.0.0:$XPRA_PORT \
    --html=off \
    --daemon=no \
    --exit-with-children=yes \
    --start-child="$AMC_CMD" \
    --xvfb="Xvfb +extension Composite -screen 0 1920x1080x24+32 -nolisten tcp -noreset" \
    --pulseaudio=no \
    --notifications=no \
    --mdns=no \
    --keyboard-layout=fr \
    --keyboard-model=apple \
    --log-file=/tmp/xpra.log
