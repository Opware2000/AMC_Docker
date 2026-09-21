#!/bin/bash
# ============================================================
# launch.sh — alias de compatibilité
# Lance l'interface GTK ; pour l'interface web : ./launch-web.sh
# ============================================================
exec "$(dirname "$0")/launch-gtk.sh" "$@"
