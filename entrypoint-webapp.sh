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
    NQCM_DEST="$TEXMFLOCAL/tex/latex/nQcm"
    rsync -a --checksum "$NQCM_SRC/" "$NQCM_DEST/"
    # Le fichier est nQCM.sty mais certains documents écrivent
    # \usepackage{nQcm} : macOS est insensible à la casse, Linux non.
    # On expose les deux orthographes.
    if [ -f "$NQCM_DEST/nQCM.sty" ] && [ ! -e "$NQCM_DEST/nQcm.sty" ]; then
        ln -s nQCM.sty "$NQCM_DEST/nQcm.sty"
    fi
    if [ -f "$NQCM_DEST/nQcm.sty" ] && [ ! -e "$NQCM_DEST/nQCM.sty" ]; then
        ln -s nQcm.sty "$NQCM_DEST/nQCM.sty"
    fi
    mktexlsr >/dev/null 2>&1 || texhash >/dev/null 2>&1 || true
fi

exec "$@"
