#!/bin/bash
# ============================================================
# launch-web.sh — Interface AMC dans le navigateur (amc-webapp)
#                 http://localhost:8080
# Pour l'interface bureau (GTK), voir launch-gtk.sh
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Auto-Multiple-Choice — Interface Web  ║${NC}"
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
    exit 1
fi
echo -e "${GREEN}✓ Docker opérationnel${NC}"

# ── 2. Image de base (le serveur web en dérive) ─────────────
if docker image inspect amc-nqcm:latest &>/dev/null; then
    echo -e "${GREEN}✓ Image de base présente${NC}"
else
    echo -e "${YELLOW}→ Image de base absente : construction (10 à 20 minutes)...${NC}"
    docker compose build amc
    echo -e "${GREEN}✓ Image de base construite${NC}"
fi

# ── 3. Avertissement si l'interface GTK tourne aussi ────────
if docker ps --format '{{.Names}}' | grep -q '^amc_docker-amc-1$'; then
    echo -e "${YELLOW}⚠ L'interface GTK tourne aussi : évitez d'ouvrir le même"
    echo -e "  projet dans les deux (verrous et caches partagés).${NC}"
fi

# ── 4. Construction et démarrage du serveur web ─────────────
echo ""
echo -e "${GREEN}→ Construction et démarrage du serveur web...${NC}"
docker compose --profile webapp up -d --build amc-web

# ── 5. Attente de disponibilité HTTP ────────────────────────
URL="http://localhost:8080"
echo -e "${YELLOW}→ Attente du serveur ${URL} ...${NC}"
READY=0
for i in {1..40}; do
    if curl -sf -o /dev/null "$URL/"; then
        READY=1
        break
    fi
    sleep 1
done

if [ "$READY" -ne 1 ]; then
    echo -e "${RED}✗ Le serveur n'a pas répondu${NC}"
    docker compose --profile webapp logs --tail=30 amc-web
    exit 1
fi

echo -e "${GREEN}✓ Serveur web prêt${NC}"
# AMC_NO_BROWSER=1 pour ne pas ouvrir le navigateur (utile en test)
if [ -z "$AMC_NO_BROWSER" ]; then
    open "$URL" 2>/dev/null || true
fi

echo ""
echo -e "  Interface : ${BLUE}${URL}${NC}"
echo -e "  Logs      : docker compose --profile webapp logs -f amc-web"
echo -e "  Arrêt     : ./stop-web.sh"
