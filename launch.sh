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

# ── 3. Pont Mac-bridge (ouvre les fichiers avec les apps Mac) ──────────────
# Tuer tout process qui occuperait déjà le port 6081
lsof -ti tcp:6081 | xargs kill -9 2>/dev/null || true
BRIDGE_PID=""
if command -v python3 &>/dev/null; then
    python3 - <<'BRIDGE_EOF' &
import http.server, urllib.parse, subprocess

PATH_MAP = {
    "/amc/controles": "/Users/nicolasogier/Library/CloudStorage/Dropbox/COURS/CONTROLES",
    "/amc/scan":      "/Users/nicolasogier/Library/CloudStorage/Dropbox/COURS/CONTROLES/SCAN",
    "/nqcm":          "/Users/nicolasogier/workspaces/Latex/nQcm",
}
APP_MAP = {
    "texmaker":          None,
    "libreoffice":       "LibreOffice",
    "gnome-text-editor": "TextEdit",
    "nautilus":          "Finder",
    "gnumeric":          "Numbers",
    "papers":            "Preview",
    "eog":               "Preview",
}

class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        params = urllib.parse.parse_qs(urllib.parse.urlparse(self.path).query)
        file = params.get("file", [""])[0]
        app  = params.get("app",  [""])[0]
        mac_path = file
        for cp, mp in PATH_MAP.items():
            if file.startswith(cp):
                mac_path = mp + file[len(cp):]
                break
        cmd = ["open"]
        mac_app = APP_MAP.get(app)
        if mac_app:
            cmd += ["-a", mac_app]
        cmd.append(mac_path)
        subprocess.Popen(cmd)
        self.send_response(200); self.end_headers()
    def log_message(self, *a): pass

http.server.HTTPServer(("127.0.0.1", 6081), Handler).serve_forever()
BRIDGE_EOF
    BRIDGE_PID=$!
    echo -e "${GREEN}✓ Pont Mac-bridge démarré (port 6081)${NC}"
fi

# Nettoyage d'un éventuel conteneur précédent encore actif
docker compose down 2>/dev/null || true

# ── 4. Lancement d'AMC ──────────────────────────────────────
echo ""
echo -e "${GREEN}→ Lancement d'AMC (mode Xpra)...${NC}"
echo ""

docker compose up --remove-orphans -d

# Attendre que xpra ait réellement ouvert le TCP socket (pas juste le port Docker)
# nc -z retourne vrai dès que Docker mappe le port, avant que xpra le bind — on attend "xpra is ready"
echo -e "${YELLOW}→ Attente du serveur Xpra...${NC}"
XPRA_READY=0
for i in {1..30}; do
    sleep 1
    # xpra écrit sur stderr (capturé par docker logs) depuis que --log-file a été retiré
    if docker logs amc_docker-amc-1 2>&1 | grep -q "xpra is ready"; then
        XPRA_READY=1
        break
    fi
done

if [ "$XPRA_READY" -eq 1 ]; then
    echo -e "${GREEN}✓ Xpra disponible${NC}"
    echo ""
    echo -e "${BLUE}→ Ouverture de la fenêtre AMC...${NC}"
    # Lance xpra attach en arrière-plan (ouvre la fenêtre native Mac)
    # 127.0.0.1 force IPv4 — Docker n'écoute pas sur IPv6
    /Applications/Xpra.app/Contents/MacOS/Xpra attach --username=root tcp://127.0.0.1:14500/ &
    XPRA_CLIENT_PID=$!
    echo -e "${YELLOW}  (Fermez la fenêtre AMC ou appuyez sur Ctrl+C pour arrêter)${NC}"

    # Arrêt propre sur Ctrl+C ou fermeture de la fenêtre AMC
    cleanup() {
        echo ""
        echo -e "${BLUE}→ Arrêt d'AMC...${NC}"
        kill "$XPRA_CLIENT_PID" 2>/dev/null || true
        docker compose down
        [ -n "$BRIDGE_PID" ] && kill "$BRIDGE_PID" 2>/dev/null || true
    }
    trap cleanup INT TERM

    # Attendre la fin du client Xpra (fenêtre fermée) ou un signal
    wait "$XPRA_CLIENT_PID" 2>/dev/null || true
    cleanup
else
    echo -e "${RED}✗ Le serveur Xpra n'a pas démarré${NC}"
    docker compose logs
    docker compose down
    exit 1
fi

echo ""
echo -e "${BLUE}AMC terminé.${NC}"
