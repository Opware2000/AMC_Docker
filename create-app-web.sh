#!/bin/bash
# ============================================================
# create-app-web.sh — Crée « Auto Multiple Choice Web.app »
# Raccourci pour : ./create-app.sh web
# ============================================================
exec "$(dirname "$0")/create-app.sh" web "$@"
