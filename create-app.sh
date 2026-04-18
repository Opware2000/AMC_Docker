#!/bin/bash
# ============================================================
# create-app.sh — Crée AMC.app pour le Dock macOS
# À exécuter une seule fois depuis le dossier amc-docker/
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Répertoire absolu du projet amc-docker (là où se trouve ce script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCH_SCRIPT="$SCRIPT_DIR/launch.sh"

# Destination de l'application
APP_NAME="Auto Multiple Choice"
APP_PATH="$HOME/Applications/$APP_NAME.app"

echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Création de « $APP_NAME.app »  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# ── Vérifications ────────────────────────────────────────────
if [ ! -f "$LAUNCH_SCRIPT" ]; then
    echo -e "${RED}✗ launch.sh introuvable dans $SCRIPT_DIR${NC}"
    echo "  Exécutez ce script depuis le dossier amc-docker/"
    exit 1
fi

if [ ! -x "$LAUNCH_SCRIPT" ]; then
    chmod +x "$LAUNCH_SCRIPT"
fi

# ── Création de la structure .app ────────────────────────────
echo -e "${GREEN}→ Création de la structure .app...${NC}"
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

# ── Info.plist ───────────────────────────────────────────────
cat > "$APP_PATH/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launcher</string>
    <key>CFBundleIconFile</key>
    <string>amc</string>
    <key>CFBundleIdentifier</key>
    <string>net.auto-multiple-choice.docker</string>
    <key>CFBundleName</key>
    <string>Auto Multiple Choice</string>
    <key>CFBundleDisplayName</key>
    <string>Auto Multiple Choice</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <!-- Indique que c'est une vraie app (icône dans le Dock) -->
    <key>LSUIElement</key>
    <false/>
    <!-- Autorise le lancement depuis n'importe où -->
    <key>LSEnvironment</key>
    <dict>
        <key>PATH</key>
        <string>/usr/local/bin:/usr/bin:/bin:/opt/homebrew/bin</string>
    </dict>
</dict>
</plist>
PLIST

# ── Exécutable principal ─────────────────────────────────────
# Utilise AppleScript pour ouvrir un Terminal et lancer launch.sh
# L'utilisateur voit les logs (utile pour le premier lancement)
cat > "$APP_PATH/Contents/MacOS/launcher" << LAUNCHER
#!/bin/bash

LAUNCH_SCRIPT="$LAUNCH_SCRIPT"

# Ouvre un Terminal dédié et lance le script
osascript << APPLESCRIPT
tell application "Terminal"
    activate
    -- Ouvre un nouvel onglet (ou fenêtre si Terminal n'était pas ouvert)
    set newTab to do script "echo ''; echo '🚀  Démarrage de Auto Multiple Choice…'; echo ''; cd \\"$SCRIPT_DIR\\" && ./launch.sh; echo ''; echo '✅  AMC fermé.'"
    -- Renomme la fenêtre pour la retrouver facilement
    set custom title of newTab to "Auto Multiple Choice"
end tell
APPLESCRIPT
LAUNCHER
chmod +x "$APP_PATH/Contents/MacOS/launcher"

# ── Icône ────────────────────────────────────────────────────
echo -e "${GREEN}→ Création de l'icône...${NC}"

# Télécharge l'icône officielle d'AMC si possible
AMC_ICON_URL="https://gitlab.com/a10684/auto-multiple-choice/-/raw/master/doc/auto-multiple-choice.png"
TMP_PNG="/tmp/amc_icon.png"
ICONSET_DIR="/tmp/amc.iconset"

ICON_OK=false

if curl -fsSL --max-time 10 "$AMC_ICON_URL" -o "$TMP_PNG" 2>/dev/null; then
    # Vérifie que c'est bien une image PNG valide
    if file "$TMP_PNG" | grep -q "PNG"; then
        echo -e "${GREEN}  ✓ Icône AMC téléchargée${NC}"

        # Crée l'iconset avec toutes les résolutions requises par macOS
        mkdir -p "$ICONSET_DIR"
        for SIZE in 16 32 64 128 256 512; do
            sips -z $SIZE $SIZE "$TMP_PNG" \
                --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png"       &>/dev/null
            DOUBLE=$((SIZE * 2))
            sips -z $DOUBLE $DOUBLE "$TMP_PNG" \
                --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png"    &>/dev/null
        done

        # Compile en .icns
        iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/amc.icns" 2>/dev/null \
            && ICON_OK=true \
            || echo -e "${YELLOW}  ⚠ iconutil a échoué — icône par défaut${NC}"

        rm -rf "$ICONSET_DIR" "$TMP_PNG"
    fi
fi

if [ "$ICON_OK" = false ]; then
    echo -e "${YELLOW}  ⚠ Icône AMC non disponible — utilisation de l'icône Terminal${NC}"
    # Copie l'icône de Terminal comme fallback
    TERMINAL_ICON="/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns"
    [ -f "$TERMINAL_ICON" ] && cp "$TERMINAL_ICON" "$APP_PATH/Contents/Resources/amc.icns"
fi

# ── Finalisation ─────────────────────────────────────────────
# Force macOS à recalculer l'icône du Finder
touch "$APP_PATH"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  ✅  Auto Multiple Choice.app créé avec succès !     ║${NC}"
echo -e "${GREEN}╠══════════════════════════════════════════════════════╣${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Emplacement :                                       ║${NC}"
echo -e "${GREEN}║  ~/Applications/Auto Multiple Choice.app             ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}║  Pour ajouter au Dock :                              ║${NC}"
echo -e "${GREEN}║  1. Ouvrez le Finder                                 ║${NC}"
echo -e "${GREEN}║  2. Allez dans Aller > Applications (Shift+Cmd+A)    ║${NC}"
echo -e "${GREEN}║     (choisissez « Applications » dans la colonne     ║${NC}"
echo -e "${GREEN}║      de gauche, pas le dossier système)              ║${NC}"
echo -e "${GREEN}║  3. Glissez « Auto Multiple Choice »                 ║${NC}"
echo -e "${GREEN}║     dans le Dock                                     ║${NC}"
echo -e "${GREEN}║                                                      ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"
echo ""

# Ouvre le dossier Applications pour faciliter le drag & drop vers le Dock
open "$HOME/Applications"
