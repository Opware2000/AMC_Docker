#!/usr/bin/env python3
"""Fusionne les traductions de l'overlay dans les catalogues amont.

Utilisé au build par Dockerfile.webapp, avant `make` (qui compile les .mo).
Les catalogues amont restent la source principale : on ne fait qu'ajouter
(ou remplacer) les clés `webapp.*` définies dans extra-<lang>.po.

Usage : merge_po.py <dossier translations> <dossier extra>
        merge_po.py /amc-web/server/translations /tmp/i18n
"""

import os
import sys

from babel.messages.pofile import read_po, write_po


def merge(lang, base_dir, extra_dir):
    upstream = os.path.join(base_dir, lang, "LC_MESSAGES", "messages.po")
    extra = os.path.join(extra_dir, "extra-%s.po" % lang)
    if not os.path.exists(upstream):
        print("i18n: %s introuvable, ignoré" % upstream)
        return
    if not os.path.exists(extra):
        print("i18n: %s introuvable, ignoré" % extra)
        return

    with open(upstream, "rb") as f:
        catalog = read_po(f)
    with open(extra, "rb") as f:
        overlay = read_po(f)

    added = replaced = 0
    for message in overlay:
        if not message.id or message.id == "":
            continue
        if message.id in catalog:
            catalog[message.id].string = message.string
            replaced += 1
        else:
            catalog.add(message.id, message.string)
            added += 1

    with open(upstream, "wb") as f:
        write_po(f, catalog, width=79)

    print("i18n: %s — %d ajoutée(s), %d remplacée(s)" % (lang, added, replaced))


def main():
    base_dir = sys.argv[1] if len(sys.argv) > 1 else "server/translations"
    extra_dir = sys.argv[2] if len(sys.argv) > 2 else "webapp/i18n"
    for lang in ("fr", "en"):
        merge(lang, base_dir, extra_dir)


if __name__ == "__main__":
    main()
