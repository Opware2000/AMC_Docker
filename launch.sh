#!/bin/bash
# ============================================================
# launch.sh — Lance AMC Docker sur MacBook Air Apple Silicon
#             Mode VNC (pas besoin de XQuartz)
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

# ── 2. Construction de l'image si nécessaire ────────────────
if ! docker image inspect amc-nqcm:latest &>/dev/null; then
    echo ""
    echo -e "${YELLOW}→ Première utilisation : construction de l'image Docker...${NC}"
    echo -e "${YELLOW}  Cela peut prendre 10 à 20 minutes...${NC}"
    echo ""
    docker compose build
    echo -e "${GREEN}✓ Image construite${NC}"
else
    echo -e "${GREEN}✓ Image déjà construite${NC}"
fi

# ── 3. Lancement d'AMC ──────────────────────────────────────
echo ""
echo -e "${GREEN}→ Lancement d'AMC (mode VNC)...${NC}"
echo ""

docker compose up --remove-orphans -d

# Attendre que x11vnc soit prêt
echo -e "${YELLOW}→ Attente du serveur VNC...${NC}"
for i in {1..20}; do
    sleep 1
    if curl -sf http://localhost:6080/vnc.html -o /dev/null 2>/dev/null; then
        break
    fi
done

if curl -sf http://localhost:6080/vnc.html -o /dev/null 2>/dev/null; then
    echo -e "${GREEN}✓ noVNC disponible${NC}"
    echo ""
    echo -e "${BLUE}→ Connexion à AMC :${NC}"
    echo -e "   ${YELLOW}http://localhost:6080/vnc.html?resize=scale${NC}"
    echo ""
    open -a Safari "http://localhost:6080/vnc.html?resize=scale"
    echo -e "${YELLOW}  (Astuce : ⌘+Ctrl+F pour passer en plein écran)${NC}"
    echo -e "${YELLOW}  (Appuyez sur Entrée pour arrêter AMC)${NC}"
    read -r
    docker compose down
else
    echo -e "${RED}✗ Le serveur noVNC n'a pas démarré${NC}"
    docker compose logs
    docker compose down
    exit 1
fi

echo ""
echo -e "${BLUE}AMC terminé.${NC}"
