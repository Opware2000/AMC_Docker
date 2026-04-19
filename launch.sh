#!/bin/bash
# ============================================================
# launch.sh — Lance AMC Docker sur MacBook Air Apple Silicon
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Auto-Multiple-Choice — Lanceur Mac    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

# ── 1. Vérification Docker ──────────────────────────────────
if ! command -v docker &>/dev/null; then
    echo -e "${RED}✗ Docker n'est pas installé${NC}"
    echo "  https://www.docker.com/products/docker-desktop/"
    exit 1
fi

if ! docker info &>/dev/null; then
    echo -e "${RED}✗ Docker Desktop n'est pas lancé${NC}"
    echo "  Lancez Docker Desktop et réessayez."
    exit 1
fi
echo -e "${GREEN}✓ Docker opérationnel${NC}"

# ── 2. Vérification XQuartz ─────────────────────────────────
XQUARTZ_APP="/Applications/Utilities/XQuartz.app"
if [ ! -d "$XQUARTZ_APP" ]; then
    echo -e "${RED}✗ XQuartz n'est pas installé${NC}"
    echo "  brew install --cask xquartz  ou  https://www.xquartz.org/"
    exit 1
fi
echo -e "${GREEN}✓ XQuartz trouvé${NC}"

# ── 3. Lancement de XQuartz ─────────────────────────────────
if ! pgrep -x "Xquartz" &>/dev/null && ! pgrep -f "XQuartz" &>/dev/null; then
    echo -e "${YELLOW}→ Démarrage de XQuartz...${NC}"
    open -a XQuartz
    echo "  Attente du démarrage (15 secondes max)..."
    for i in {1..15}; do
        sleep 1
        if xdpyinfo -display :0 &>/dev/null 2>&1; then
            break
        fi
    done
else
    echo -e "${GREEN}✓ XQuartz déjà lancé${NC}"
fi

# ── 4. Vérification des préférences XQuartz pour le trackpad ─
# XQuartz doit avoir "Emulate three button mouse" activé pour le clic droit
# et "Follow system keyboard" pour le clavier Mac.
# On affiche un rappel si c'est la première fois.
XQUARTZ_PREFS="$HOME/Library/Preferences/org.xquartz.X11.plist"
XQUARTZ_CHECKED="$HOME/.amc_xquartz_checked"

if [ ! -f "$XQUARTZ_CHECKED" ]; then
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║  PREMIÈRE UTILISATION — Vérifiez XQuartz (trackpad)  ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║  Dans XQuartz > Réglages :                           ║${NC}"
    echo -e "${YELLOW}║                                                      ║${NC}"
    echo -e "${YELLOW}║  Onglet « Entrée » :                                 ║${NC}"
    echo -e "${YELLOW}║  ☑ Émuler une souris à 3 boutons                     ║${NC}"
    echo -e "${YELLOW}║    → Clic droit = deux doigts sur le trackpad        ║${NC}"
    echo -e "${YELLOW}║    → Clic milieu = Option + clic                     ║${NC}"
    echo -e "${YELLOW}║  ☑ Utiliser le réglage OSX de vitesse souris         ║${NC}"
    echo -e "${YELLOW}║                                                      ║${NC}"
    echo -e "${YELLOW}║  Onglet « Sécurité » :                               ║${NC}"
    echo -e "${YELLOW}║  ☑ Autoriser les connexions réseau                   ║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo "  Appuyez sur Entrée une fois XQuartz configuré..."
    read -r
    touch "$XQUARTZ_CHECKED"
fi

# ── 4b. Forcer nolisten_tcp=0 (XQuartz doit écouter en TCP) ──
if defaults read org.macosforge.xquartz.X11 nolisten_tcp 2>/dev/null | grep -q 1; then
    echo -e "${YELLOW}→ Correction nolisten_tcp (XQuartz doit redémarrer)...${NC}"
    defaults write org.macosforge.xquartz.X11 nolisten_tcp 0
    pkill -x Xquartz 2>/dev/null || true
    sleep 2
    open -a XQuartz
    sleep 5
fi

# ── 5. Vérification TCP XQuartz (port 6000) ─────────────────
if ! nc -z 127.0.0.1 6000 2>/dev/null; then
    echo -e "${RED}✗ XQuartz n'écoute pas sur TCP (port 6000)${NC}"
    echo ""
    echo -e "${YELLOW}  Action requise :${NC}"
    echo "  1. Ouvrez XQuartz > Réglages > onglet « Sécurité »"
    echo "  2. Cochez ☑ « Autoriser les connexions réseau »"
    echo "  3. Quittez XQuartz complètement (⌘Q)"
    echo "  4. Relancez : open -a XQuartz"
    echo "  5. Relancez ce script"
    echo ""
    # Réinitialise le flag pour forcer l'affichage du guide au prochain lancement
    rm -f "$XQUARTZ_CHECKED"
    exit 1
fi

# ── 6. Configuration xhost ──────────────────────────────────
# xhost + nécessaire car Docker connecte via l'IP du gateway VM (pas 127.0.0.1)
echo -e "${YELLOW}→ Autorisation X11 depuis Docker...${NC}"
xhost + 2>/dev/null || true
echo -e "${GREEN}✓ Accès X11 configuré${NC}"

# ── 7. Construction de l'image si nécessaire ────────────────
if ! docker image inspect amc-nqcm:latest &>/dev/null; then
    echo ""
    echo -e "${YELLOW}→ Première utilisation : construction de l'image Docker...${NC}"
    echo -e "${YELLOW}  texlive-full ≈ 4 Go — comptez 20 à 40 minutes${NC}"
    echo ""
    docker compose build
    echo -e "${GREEN}✓ Image construite${NC}"
else
    echo -e "${GREEN}✓ Image déjà construite${NC}"
fi

# ── 8. Lancement d'AMC ──────────────────────────────────────
echo ""
echo -e "${GREEN}→ Lancement d'AMC...${NC}"
echo ""

DISPLAY=host.docker.internal:0 docker compose up --remove-orphans

echo ""
echo -e "${BLUE}AMC terminé.${NC}"
