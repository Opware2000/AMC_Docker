# ============================================================
# Auto-Multiple-Choice — Docker image pour Apple Silicon (ARM64)
# Base : texlive/texlive (TeX Live 2026 complet, upstream, arm64)
#        → contient TOUS les paquets LaTeX (simplekv, lucide-icons, …)
#          et les binaires sont liés dans /usr/bin (pas de PATH à gérer)
# ============================================================

# Version de l'image — surchargez avec : --build-arg AMC_VERSION=1.2.0
ARG AMC_VERSION=dev
ARG AMC_BUILD_DATE
ARG AMC_VCS_REF

# Série Ubuntu du PPA AMC « test » à utiliser (binaires ABI-compatibles forky)
ARG AMC_PPA_SUITE=stonking

FROM texlive/texlive:latest

# Ré-exposé dans le stage pour les LABEL (sinon variable non définie)
ARG AMC_VERSION
ARG AMC_BUILD_DATE
ARG AMC_VCS_REF
ARG AMC_PPA_SUITE

# Labels OCI (https://github.com/opencontainers/image-spec/blob/master/annotations.md)
LABEL org.opencontainers.image.title="AMC Docker (nQCM)" \
      org.opencontainers.image.description="Auto-Multiple-Choice + classe LaTeX nQCM pour Apple Silicon" \
      org.opencontainers.image.source="https://github.com/Opware2000/AMC_Docker" \
      org.opencontainers.image.licenses="GPL-3.0-or-later" \
      org.opencontainers.image.version="${AMC_VERSION}" \
      org.opencontainers.image.created="${AMC_BUILD_DATE}" \
      org.opencontainers.image.revision="${AMC_VCS_REF}"

# Évite les questions interactives pendant apt
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=fr_FR.UTF-8
ENV LC_ALL=fr_FR.UTF-8
ENV LANGUAGE=fr_FR:fr

# ── 0. Autoriser les fichiers de locale française ─
RUN echo 'path-include /usr/share/locale/fr/*' \
    >> /etc/dpkg/dpkg.cfg.d/docker

# ── 0b. Clé GPG Xpra ─────
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    && curl -fsSL https://xpra.org/xpra.asc -o /usr/share/keyrings/xpra.asc \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 0c. Dépôt PPA AMC « test » (Alexis Bienvenüe, développeur d'AMC) ─
# La base est Debian : le PPA ne publie que des paquets Ubuntu. On utilise la
# série « stonking » (Ubuntu 26.10), dont les binaires sont ABI-compatibles
# avec Debian forky (libopencv-*-410, libpoppler-glib8t64, glibc ≥ 2.43).
# Le pinning empêche tout autre paquet Ubuntu de polluer la base Debian.
ARG AMC_PPA_SUITE
RUN curl -fsSL \
      "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0xF4ADAFE459DDDD6AE795434D5BEA485C346753E7" \
      -o /usr/share/keyrings/amc-ppa.asc \
    && printf 'Types: deb\nURIs: https://ppa.launchpadcontent.net/alexis.bienvenue/test/ubuntu\nSuites: %s\nComponents: main\nArchitectures: arm64\nSigned-By: /usr/share/keyrings/amc-ppa.asc\n' \
       "$AMC_PPA_SUITE" > /etc/apt/sources.list.d/amc-ppa.sources \
    && printf 'Package: *\nPin: release o=LP-PPA-alexis.bienvenue-test\nPin-Priority: 100\n\nPackage: auto-multiple-choice auto-multiple-choice-common\nPin: release o=LP-PPA-alexis.bienvenue-test\nPin-Priority: 990\n' \
       > /etc/apt/preferences.d/amc-ppa

# ── 1. Dépendances système + AMC + locales ──────────────────
# NB : aucun paquet apt « texlive-* » — TeX Live est déjà complet dans
#      l'image de base, et un paquet fictif (texlive-local) satisfait les
#      dépendances texlive d'AMC sans installer un second TeX Live.
# NB : auto-multiple-choice provient du PPA « test » (section 0c), pas de
#      Debian — le pinning garantit la sélection du PPA.
RUN apt-get update && apt-get install -y --no-install-recommends \
    # AMC (version PPA « test ») et ses dépendances
    auto-multiple-choice \
    # Polices requises par AMC
    fonts-linuxlibertine \
    fonts-dejavu \
    fonts-freefont-otf \
    # Outils image utilisés par AMC
    imagemagick \
    ghostscript \
    # PDF / scan
    poppler-utils \
    netpbm \
    qpdf \
    librsvg2-common \
    # Modules Perl pour l'export AMC (remplace l'ancien build cpanm
    # OpenOffice::OODoc, désormais packagé)
    libopenoffice-oodoc-perl \
    libpango-perl \
    libgtk3-perl \
    # Notifications bureau
    libdesktop-notify-perl \
    libnotify-bin \
    # gnumeric
    gnumeric \
    # Utilitaires
    locales \
    rsync \
    unzip \
    wget \
    # Terminal pour debuguer
    xterm \
    # X11
    x11-xserver-utils \
    x11-utils \
    x11-xkb-utils \
    xkb-data \
    xvfb \
    && echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && printf 'LANG=fr_FR.UTF-8\nLC_ALL=fr_FR.UTF-8\nLANGUAGE=fr_FR:fr\n' > /etc/default/locale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── 1b. Réinstaller le paquet de traductions AMC ─
RUN apt-get update \
    && apt-get install --reinstall -y auto-multiple-choice-common \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 1c. Xpra server (dépôt stable, suite = celle de la base) ─────
RUN . /etc/os-release \
    && SUITE="${VERSION_CODENAME:-trixie}" \
    && printf 'Types: deb\nURIs: https://xpra.org\nSuites: %s\nComponents: main\nSigned-By: /usr/share/keyrings/xpra.asc\nArchitectures: arm64\n' "$SUITE" \
    > /etc/apt/sources.list.d/xpra.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    xpra-server \
    xpra-x11 \
    xpra-client-gtk3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 2. Rendre automultiplechoice.sty visible au TeX Live upstream ─
# Le paquet Debian l'installe dans /usr/share/texmf, que TeX Live upstream
# ne parcourt pas : on le copie dans TEXMFLOCAL puis on réindexe.
RUN TL="$(kpsewhich -var-value TEXMFLOCAL)" \
    && mkdir -p "$TL/tex/latex/AMC" \
    && cp -f /usr/share/texmf/tex/latex/AMC/automultiplechoice.sty "$TL/tex/latex/AMC/" \
    && mktexlsr

# ── 3. Stubs pour commandes optionnelles + xterm ────────────
COPY libreoffice-stub.sh /usr/local/bin/libreoffice
RUN chmod +x /usr/local/bin/libreoffice
RUN for cmd in texmaker gnome-text-editor papers eog xterm; do \
    printf '#!/bin/sh\ncurl -sf "http://host.docker.internal:6081/open?file=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${1:-}" 2>/dev/null)&app=%s" || true\n' "$cmd" \
    > "/usr/local/bin/$cmd" && chmod +x "/usr/local/bin/$cmd"; \
    done && \
    printf '#!/bin/sh\n# nautilus reçoit file:///chemin\npath="${1#file://}"\ncurl -sf "http://host.docker.internal:6081/open?file=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$path" 2>/dev/null)&app=nautilus" || true\n' \
    > /usr/local/bin/nautilus && chmod +x /usr/local/bin/nautilus

# ── 4. Politique ImageMagick (IM6 ou IM7 selon la version) ──────
RUN for f in /etc/ImageMagick-*/policy.xml; do \
    [ -f "$f" ] && sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' "$f"; \
    done || true

# ── 5. Répertoires de travail ────────────────────
RUN mkdir -p \
    /root/.AMC.d \
    /amc/projets \
    /amc/scan \
    /amc/controles \
    /texmf-local/nQcm

# ── 6. Config fluxbox minimale ──
RUN mkdir -p /root/.fluxbox && \
    printf 'session.styleFile: /usr/share/fluxbox/styles/bloe\n' > /root/.fluxbox/init && \
    printf '#!/bin/sh\n# no wallpaper\n' > /root/.fluxbox/startup && \
    chmod +x /root/.fluxbox/startup

# ── 7. Remplacer notify-send par un no-op ─
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/notify-send && \
    chmod +x /usr/local/bin/notify-send

# ── 8. Entrypoint ────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

# ── 9. Empreinte des fichiers de build ───────────────────────
# launch.sh compare ce label au hachage local pour décider d'un rebuild.
# Déclaré en fin de Dockerfile : un changement de hash n'invalide que les
# dernières couches (pas les apt/TeX déjà en cache).
ARG AMC_BUILD_HASH
LABEL amc.build.hash="${AMC_BUILD_HASH}"

WORKDIR /amc/controles
ENTRYPOINT ["/entrypoint.sh"]
CMD ["auto-multiple-choice", "gui"]
