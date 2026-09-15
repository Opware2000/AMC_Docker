# ============================================================
# Auto-Multiple-Choice — Docker image pour Apple Silicon (ARM64)
# Base : Debian bookworm + TeX Live upstream
# ============================================================

# Version de l'image — surchargez avec : --build-arg AMC_VERSION=1.2.0
ARG AMC_VERSION=dev
ARG AMC_BUILD_DATE
ARG AMC_VCS_REF

FROM debian:bookworm

# Labels OCI (https://github.com/opencontainers/image-spec/blob/master/annotations.md)
LABEL org.opencontainers.image.title="AMC Docker (nQCM)" \
      org.opencontainers.image.description="Auto-Multiple-Chance + classe LaTeX nQCM pour Apple Silicon" \
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

# ── 1. TeX Live + dépendances système + lucide-icons ───────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # TeX Live
    texlive \
    texlive-xetex \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-lang-french \
    texlive-latex-extra \
    texlive-pictures \
    # Packages LaTeX manquants
    texlive-latex-extra-doc \
    # Terminal pour debuguer
    xterm \
    # AMC et ses dépendances
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
    # Utilitaires
    locales \
    wget \
    unzip \
    rsync \
    # Notifications bureau
    libdesktop-notify-perl \
    libnotify-bin \
    # Modules Perl pour l'export AMC
    libpango-perl \
    libgtk3-perl \
    # X11
    x11-xserver-utils \
    x11-utils \
    x11-xkb-utils \
    xkb-data \
    xvfb \
    # gnumeric
    gnumeric \
    && echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && printf 'LANG=fr_FR.UTF-8\nLC_ALL=fr_FR.UTF-8\nLANGUAGE=fr_FR:fr\n' > /etc/default/locale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── 1b. Installer simplekv et lucide-icons via tlmgr sans les échecs silencieux ──
RUN tlmgr update --self --all \
    && tlmgr install simplekv lucide-icons \
    && texhash

# ── 1c. Xpra server (dépôt stable) ─────
RUN printf 'Types: deb\nURIs: https://xpra.org\nSuites: bookworm\nComponents: main\nSigned-By: /usr/share/keyrings/xpra.asc\nArchitectures: arm64\n' \
    > /etc/apt/sources.list.d/xpra.sources \
    && apt-get update \
    && apt-get install -y --no-install-recommends \
    xpra-server \
    xpra-x11 \
    xpra-client-gtk3 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 2. Réinstaller le paquet de traductions AMC ─
RUN apt-get update \
    && apt-get install --reinstall -y auto-multiple-choice-common \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 2b. Module Perl OpenOffice::OODoc ───────
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    cpanminus \
    build-essential \
    libarchive-zip-perl \
    libxml-parser-perl \
    libxml-twig-perl \
    && cpanm --notest OpenOffice::OODoc \
    && apt-get purge -y cpanminus build-essential \
    && apt-get autoremove -y \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 3. Stubs pour commandes optionnelles ────────────
COPY libreoffice-stub.sh /usr/local/bin/libreoffice
RUN chmod +x /usr/local/bin/libreoffice
RUN for cmd in texmaker gnome-text-editor papers eog; do \
    printf '#!/bin/sh\ncurl -sf "http://host.docker.internal:6081/open?file=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "${1:-}" 2>/dev/null)&app=%s" || true\n' "$cmd" \
    > "/usr/local/bin/$cmd" && chmod +x "/usr/local/bin/$cmd"; \
    done && \
    printf '#!/bin/sh\n# nautilus reçoit file:///chemin\npath="${1#file://}"\ncurl -sf "http://host.docker.internal:6081/open?file=$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))" "$path" 2>/dev/null)&app=nautilus" || true\n' \
    > /usr/local/bin/nautilus && chmod +x /usr/local/bin/nautilus

# ── 4. Politique ImageMagick ──────────────────────
RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' \
    /etc/ImageMagick-6/policy.xml || true

# ── 5. Répertoires de travail ────────────────────
RUN mkdir -p \
    /root/.AMC.d \
    /amc/projets \
    /amc/scan \
    /amc/controles \
    /texmf-local/nQcm \
    /usr/share/texmf-local/tex/latex/lucide-icons

# ── 5b. Copier lucide-icons.sty ──────────────────
COPY lucide-icons.sty /usr/share/texmf-local/tex/latex/lucide-icons/
RUN texhash

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

WORKDIR /amc/controles
ENTRYPOINT ["/entrypoint.sh"]
CMD ["auto-multiple-choice", "gui"]
