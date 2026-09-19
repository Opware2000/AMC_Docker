#!/bin/bash
# ============================================================
# Entrypoint AMC webapp — installe la classe nQCM puis lance gunicorn
# (même logique nQCM que entrypoint.sh, sans la partie Xpra/GTK)
# ============================================================
set -e

NQCM_SRC="/nqcm"
if [ -d "$NQCM_SRC" ] && [ "$(ls -A "$NQCM_SRC" 2>/dev/null)" ]; then
    TEXMFLOCAL="$(kpsewhich -var-value TEXMFLOCAL 2>/dev/null || echo /usr/share/texmf)"
    echo "→ Installation de la classe nQCM dans $TEXMFLOCAL/tex/latex/nQcm"
    mkdir -p "$TEXMFLOCAL/tex/latex/nQcm"
    rsync -a --checksum "$NQCM_SRC/" "$TEXMFLOCAL/tex/latex/nQcm/"
    mktexlsr >/dev/null 2>&1 || texhash >/dev/null 2>&1 || true
fi

exec "$@"
