#!/bin/sh
# Stub libreoffice pour AMC dans Docker
# - Si appelé avec --convert-to : utilise ssconvert (gnumeric)
# - Sinon : ouvre le fichier sur le Mac via le pont bridge

if echo "$*" | grep -q "convert-to"; then
    # AMC appelle : libreoffice --headless --convert-to pdf --outdir DIR fichier.ods
    src="${@: -1}"
    outdir="."
    prev=""
    for i in "$@"; do
        [ "$prev" = "--outdir" ] && outdir="$i"
        prev="$i"
    done
    base=$(basename "$src" | sed 's/\.[^.]*$//')
    exec ssconvert "$src" "$outdir/$base.pdf" 2>/dev/null
else
    file="$1"
    [ -z "$file" ] && exit 0
    encoded=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$file" 2>/dev/null)
    curl -sf "http://host.docker.internal:6081/open?file=${encoded}&app=libreoffice" || true
fi
