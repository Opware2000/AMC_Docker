# ============================================================
# Auto-Multiple-Choice — Docker image pour Apple Silicon (ARM64)
# Base : texlive/texlive (Debian + TeX Live upstream complet, arm64)
# ============================================================
FROM texlive/texlive:latest

# Évite les questions interactives pendant apt
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=fr_FR.UTF-8
ENV LC_ALL=fr_FR.UTF-8
ENV LANGUAGE=fr_FR:fr

# ── 0. Autoriser les fichiers de locale française (filtrés par l'image slim) ─
RUN echo 'path-include /usr/share/locale/fr/*' \
    >> /etc/dpkg/dpkg.cfg.d/docker

# ── 1. Dépendances système ───────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    # AMC et ses dépendances Perl/système
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
    curl \
    unzip \
    rsync \
    # Notifications bureau (module Perl + binaire notify-send)
    libdesktop-notify-perl \
    libnotify-bin \
    # X11 — affichage et clavier
    x11-xserver-utils \
    x11-utils \
    x11-xkb-utils \
    xkb-data \
    # VNC — framebuffer virtuel + serveur VNC
    xvfb \
    x11vnc \
    fluxbox \
    # noVNC — client VNC dans le navigateur
    novnc \
    websockify \
    && echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && printf 'LANG=fr_FR.UTF-8\nLC_ALL=fr_FR.UTF-8\nLANGUAGE=fr_FR:fr\n' > /etc/default/locale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Réinstaller le paquet de traductions AMC (locales filtrées au départ) ─
RUN apt-get update \
    && apt-get install --reinstall -y auto-multiple-choice-common \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# ── 3. Stubs pour commandes optionnelles signalées manquantes par AMC ────────
RUN for cmd in texmaker libreoffice gnome-text-editor gnumeric papers eog; do \
    printf '#!/bin/sh\necho "[Docker] %s non disponible dans ce conteneur" >&2\nexit 1\n' "$cmd" \
    > "/usr/local/bin/$cmd" && chmod +x "/usr/local/bin/$cmd"; \
    done && \
    printf '#!/bin/sh\necho "[Docker] nautilus non disponible" >&2\nexit 1\n' \
    > /usr/local/bin/nautilus && chmod +x /usr/local/bin/nautilus

# ── 4. Politique ImageMagick (autorise PDF) ──────────────────
RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' \
    /etc/ImageMagick-6/policy.xml || true

# ── 3. Répertoires de travail ────────────────────────────────
RUN mkdir -p \
    /root/.AMC.d \
    /amc/projets \
    /amc/scan \
    /amc/controles \
    /texmf-local/nQcm

# ── 4. Config fluxbox minimale (pas de fond d'écran, pas de fbsetbg) ──
RUN mkdir -p /root/.fluxbox && \
    printf 'session.styleFile: /usr/share/fluxbox/styles/bloe\n' > /root/.fluxbox/init && \
    printf '#!/bin/sh\n# no wallpaper\n' > /root/.fluxbox/startup && \
    chmod +x /root/.fluxbox/startup

# ── 5. Remplacer notify-send par un no-op (silence libnotify) ─
RUN printf '#!/bin/sh\nexit 0\n' > /usr/local/bin/notify-send && \
    chmod +x /usr/local/bin/notify-send

# ── 6. Entrypoint ────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /amc/controles
ENTRYPOINT ["/entrypoint.sh"]
CMD ["auto-multiple-choice", "gui"]
