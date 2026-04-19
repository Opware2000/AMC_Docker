#!/bin/bash
# ============================================================
# Entrypoint AMC Docker — MacBook Air (trackpad, sans souris)
# - Installe la classe nQCM dans TEXMFLOCAL si présente
# - Vérifie le DISPLAY
# - Configure le clavier Mac français (Apple AZERTY)
# - Configure le trackpad / comportement souris X11
# - Configure GTK pour usage confortable sans souris
# - Lance AMC
# ============================================================

set -e

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

# ── 2. Vérification du DISPLAY ──────────────────────────────
if [ -z "$DISPLAY" ]; then
    echo -e "${RED}✗ Variable DISPLAY non définie !${NC}"
    echo "  Assurez-vous que XQuartz est lancé et que xhost est configuré."
    exit 1
fi

# Force IPv4 : getent hosts peut retourner une IPv6 inaccessible depuis Docker
_DISP_HOST=$(echo "$DISPLAY" | cut -d: -f1)
_DISP_NUM=$(echo "$DISPLAY" | cut -d: -f2-)
_DISP_IPV4=$(getent ahostsv4 "$_DISP_HOST" 2>/dev/null | head -1 | awk '{print $1}')
if [ -n "$_DISP_IPV4" ]; then
    export DISPLAY="$_DISP_IPV4:$_DISP_NUM"
fi

echo -e "${GREEN}→ DISPLAY = $DISPLAY${NC}"

if ! xset -display "$DISPLAY" q >/dev/null 2>&1; then
    echo -e "${RED}✗ Impossible de se connecter au serveur X ($DISPLAY)${NC}"
    echo "  Vérifiez que XQuartz est lancé et que xhost +127.0.0.1 a été exécuté."
    exit 1
fi

echo -e "${GREEN}✓ Serveur X accessible${NC}"

# ── 3. Configuration du clavier Mac français ─────────────────
echo -e "${GREEN}→ Configuration du clavier Mac français (Apple AZERTY)...${NC}"
if command -v setxkbmap &>/dev/null; then
    setxkbmap -model apple -layout fr -variant mac -display "$DISPLAY" 2>/dev/null \
        && echo -e "${GREEN}✓ Clavier Apple FR (variante mac) configuré${NC}" \
        || echo -e "${YELLOW}⚠ setxkbmap a échoué — clavier par défaut conservé${NC}"
else
    echo -e "${YELLOW}⚠ setxkbmap non disponible${NC}"
fi

# ── 4. Configuration trackpad / pointeur X11 ─────────────────
# Sur MacBook Air avec XQuartz, le trackpad envoie des événements souris X11.
# On ajuste :
#   - xset m : accélération du pointeur adaptée au trackpad
#              (ratio 2/1, seuil 4 px) — plus confortable sans souris physique
#   - xset r rate : délai avant répétition clavier (250 ms) + vitesse (40/s)
echo -e "${GREEN}→ Configuration du pointeur (trackpad MacBook)...${NC}"
if command -v xset &>/dev/null; then
    # Accélération modérée, seuil bas → bon compromis trackpad
    xset m 2/1 4 -display "$DISPLAY" 2>/dev/null || true
    # Répétition clavier fluide
    xset r rate 250 40 -display "$DISPLAY" 2>/dev/null || true
    echo -e "${GREEN}✓ Pointeur et clavier configurés${NC}"
fi

# ── 5. Configuration GTK pour trackpad sans souris ───────────
# AMC utilise GTK3. Ces paramètres améliorent l'ergonomie au trackpad :
#   - double_click_time élevé     → double-tap moins exigeant
#   - dnd_drag_threshold élevé    → évite les drags accidentels en tapant
#   - primary_button_warps_slider → clic simple sur scrollbar = aller à la position
#   - overlay_scrolling = false   → scrollbars toujours visibles (pas de survol requis)
echo -e "${GREEN}→ Configuration GTK3 (trackpad)...${NC}"
mkdir -p /root/.config/gtk-3.0
cat > /root/.config/gtk-3.0/settings.ini << 'GTK_EOF'
[Settings]
# Double-tap plus tolérant (défaut 250 ms → 400 ms)
gtk-double-click-time=400
# Distance tolérée pour le double-clic (défaut 5 → 8 px)
gtk-double-click-distance=8
# Seuil avant qu'un appui soit considéré comme un drag (évite les drags accidentels)
gtk-dnd-drag-threshold=12
# Clic sur la scrollbar = aller directement à la position cliquée
gtk-primary-button-warps-slider=true
# Scrollbars toujours visibles (pas de scroll "overlay" qui disparaît)
gtk-overlay-scrolling=false
# Curseur visible et clignotant
gtk-cursor-blink=true
gtk-cursor-blink-time=1200
# Menus et tooltips réactifs
gtk-tooltip-timeout=800
gtk-menu-popup-delay=200
GTK_EOF
echo -e "${GREEN}✓ GTK3 configuré pour trackpad${NC}"

# GTK2 (AMC utilise peut-être encore quelques widgets GTK2)
mkdir -p /root/.config/gtk-2.0
cat > /root/.config/gtk-2.0/gtkrc << 'GTK2_EOF'
gtk-double-click-time = 400
gtk-double-click-distance = 8
gtk-dnd-drag-threshold = 12
GTK2_EOF

# ── 6. Lancement d'AMC ──────────────────────────────────────
echo -e "${GREEN}→ Lancement de Auto-Multiple-Choice...${NC}"
echo ""
exec "$@"
