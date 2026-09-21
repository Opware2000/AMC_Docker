#!/bin/bash
# ============================================================
# create-app.sh — Crée une application macOS pour le Dock
#   ./create-app.sh          → « Auto Multiple Choice »      (GTK)
#   ./create-app.sh web      → « Auto Multiple Choice Web »  (navigateur)
#   ./create-app-web.sh      → raccourci pour le mode web
# À exécuter depuis le dossier amc-docker/
# ============================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Répertoire absolu du projet amc-docker (là où se trouve ce script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Mode : gtk (défaut) ou web ───────────────────────────────
MODE="${1:-gtk}"
case "$MODE" in
    gtk)
        APP_NAME="Auto Multiple Choice"
        LAUNCH_SCRIPT="$SCRIPT_DIR/launch-gtk.sh"
        BUNDLE_ID="net.auto-multiple-choice.docker"
        ;;
    web)
        APP_NAME="Auto Multiple Choice Web"
        LAUNCH_SCRIPT="$SCRIPT_DIR/launch-web.sh"
        BUNDLE_ID="net.auto-multiple-choice.docker.web"
        ;;
    *)
        echo "Usage: $0 [gtk|web]"
        exit 1
        ;;
esac
LAUNCH_BASENAME="$(basename "$LAUNCH_SCRIPT")"

# Destination de l'application
APP_PATH="$HOME/Applications/$APP_NAME.app"

echo -e "${BLUE}=== Création de « $APP_NAME.app » ===${NC}"
echo ""

# ── Vérifications ────────────────────────────────────────────
if [ ! -f "$LAUNCH_SCRIPT" ]; then
    echo -e "${RED}✗ $LAUNCH_BASENAME introuvable dans $SCRIPT_DIR${NC}"
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
    <string>${BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
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
# Utilise AppleScript pour ouvrir un Terminal et lancer le lanceur
# choisi. L'utilisateur voit les logs (utile au premier lancement).
cat > "$APP_PATH/Contents/MacOS/launcher" << LAUNCHER
#!/bin/bash

# Ouvre un Terminal dédié et lance le script
osascript << APPLESCRIPT
tell application "Terminal"
    activate
    set newTab to do script "echo ''; echo '🚀  Démarrage de ${APP_NAME}…'; echo ''; cd \\"$SCRIPT_DIR\\" && ./$LAUNCH_BASENAME; echo ''; echo '✅  ${APP_NAME} terminé.'"
    set custom title of newTab to "$APP_NAME"
end tell
APPLESCRIPT
LAUNCHER
chmod +x "$APP_PATH/Contents/MacOS/launcher"

# ── Icône ────────────────────────────────────────────────────
echo -e "${GREEN}→ Création de l'icône...${NC}"

AMC_ICON_URL="https://gitlab.com/auto-multiple-choice/auto-multiple-choice/-/raw/master/icons/auto-multiple-choice.svg"
TMP_SVG="/tmp/amc_icon.svg"
TMP_PNG="/tmp/amc_icon.png"
ICONSET_DIR="/tmp/amc.iconset"

ICON_OK=false

if curl -fsSL --max-time 15 "$AMC_ICON_URL" -o "$TMP_SVG" 2>/dev/null; then
    if command -v magick &>/dev/null; then
        magick -background none "$TMP_SVG" -resize 820x820 \
            -gravity center -extent 1024x1024 "$TMP_PNG" 2>/dev/null || true
    else
        qlmanage -t -s 1024 -o /tmp "$TMP_SVG" >/dev/null 2>&1
        [ -f "$TMP_SVG.png" ] && mv -f "$TMP_SVG.png" "$TMP_PNG"
    fi
    if file "$TMP_PNG" 2>/dev/null | grep -q "PNG"; then
        echo -e "${GREEN}  ✓ Icône AMC téléchargée${NC}"

        mkdir -p "$ICONSET_DIR"
        for SIZE in 16 32 64 128 256 512; do
            sips -z $SIZE $SIZE "$TMP_PNG" \
                --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}.png"       &>/dev/null
            DOUBLE=$((SIZE * 2))
            sips -z $DOUBLE $DOUBLE "$TMP_PNG" \
                --out "$ICONSET_DIR/icon_${SIZE}x${SIZE}@2x.png"    &>/dev/null
        done

        iconutil -c icns "$ICONSET_DIR" -o "$APP_PATH/Contents/Resources/amc.icns" 2>/dev/null \
            && ICON_OK=true \
            || echo -e "${YELLOW}  ⚠ iconutil a échoué — icône par défaut${NC}"

        rm -rf "$ICONSET_DIR" "$TMP_SVG" "$TMP_PNG"
    fi
fi

if [ "$ICON_OK" = false ]; then
    echo -e "${YELLOW}  ⚠ Icône AMC non disponible — utilisation de l'icône Terminal${NC}"
    TERMINAL_ICON="/System/Applications/Utilities/Terminal.app/Contents/Resources/Terminal.icns"
    [ -f "$TERMINAL_ICON" ] && cp "$TERMINAL_ICON" "$APP_PATH/Contents/Resources/amc.icns"
fi

# ── Finalisation ─────────────────────────────────────────────
touch "$APP_PATH"

echo ""
echo -e "${GREEN}✅  $APP_NAME.app créé avec succès !${NC}"
echo ""
echo -e "  Emplacement : ${BLUE}$APP_PATH${NC}"
echo -e "  Lance       : ${BLUE}./$LAUNCH_BASENAME${NC}"
echo ""
echo -e "  Pour l'ajouter au Dock : ouvrez le Finder > Applications"
echo -e "  (Shift+Cmd+A) et glissez « $APP_NAME » dans le Dock."
echo ""

# Ouvre le dossier Applications (désactivable : AMC_NO_OPEN=1)
if [ -z "$AMC_NO_OPEN" ]; then
    open "$HOME/Applications"
fi
