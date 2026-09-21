#!/bin/bash
# ============================================================
# stop-web.sh — Arrête l'interface web (conteneur amc-web)
# L'interface GTK se ferme en quittant sa fenêtre (ou Ctrl+C).
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
    echo -e "${RED}✗ Docker n'est pas disponible${NC}"
    exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -q '^amc_docker-amc-web-1$'; then
    echo -e "${YELLOW}L'interface web n'est pas en cours d'exécution.${NC}"
    exit 0
fi

echo -e "${YELLOW}→ Arrêt de l'interface web...${NC}"
docker compose --profile webapp stop amc-web >/dev/null
echo -e "${GREEN}✓ Interface web arrêtée.${NC}"
echo ""
echo -e "  Relancer : ${GREEN}./launch-web.sh${NC}"
