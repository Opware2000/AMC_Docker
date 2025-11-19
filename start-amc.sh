#!/bin/bash
set -e

echo "🚀 Démarrage de l'environnement AMC..."

# Démarrer Xvfb (serveur X virtuel)
echo "📺 Démarrage de Xvfb..."
Xvfb ${DISPLAY} -screen 0 ${VNC_RESOLUTION}x24 -ac +extension GLX +render -noreset &
XVFB_PID=$!

# Attendre que Xvfb soit prêt
sleep 2

# Démarrer le gestionnaire de fenêtres Openbox
echo "🪟 Démarrage d'Openbox..."
openbox &
OPENBOX_PID=$!

# Démarrer x11vnc
echo "🔌 Démarrage du serveur VNC sur le port ${VNC_PORT}..."
x11vnc -display ${DISPLAY} \
       -forever \
       -shared \
       -rfbport ${VNC_PORT} \
       -passwd ${VNC_PASSWORD:-amc2024} \
       -xkb \
       -noxrecord \
       -noxfixes \
       -noxdamage \
       -wait 10 \
       -bg \
       -o /tmp/x11vnc.log

# Démarrer noVNC (interface web)
echo "🌐 Démarrage de noVNC sur le port ${NOVNC_PORT}..."
websockify --web=/usr/share/novnc ${NOVNC_PORT} localhost:${VNC_PORT} &
NOVNC_PID=$!

# Attendre un peu que tout soit prêt
sleep 2

# Lancer AMC automatiquement
echo "📝 Lancement d'Auto-Multiple-Choice..."
auto-multiple-choice &

# Lancer un terminal pour l'utilisateur
xterm -geometry 100x30 -e "echo '=== Environnement AMC ===' && echo '' && echo '✅ AMC est lancé' && echo '✅ Accédez via navigateur: http://localhost:6080/vnc.html' && echo '✅ Mot de passe VNC: ${VNC_PASSWORD:-amc2024}' && echo '' && echo 'Vos projets sont dans: ~/AMC-projects' && echo 'Vos packages LaTeX perso: ~/texmf/tex/latex/' && echo '' && echo 'Outils disponibles:' && echo '  - auto-multiple-choice (QCM)' && echo '  - texmaker (Éditeur LaTeX)' && echo '  - evince / xpdf (Visualiseurs PDF)' && echo '' && bash" &

echo "✨ Environnement prêt !"
echo "📍 Interface web : http://localhost:6080/vnc.html"
echo "🔑 Mot de passe VNC : ${VNC_PASSWORD:-amc2024}"
echo ""

# Garder le conteneur actif
wait $XVFB_PID $OPENBOX_PID $NOVNC_PID