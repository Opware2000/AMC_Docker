# ============================================================
# Auto-Multiple-Choice — Docker image pour Apple Silicon (ARM64)
# Base : texlive/texlive (Debian + TeX Live upstream complet, arm64)
# ============================================================
FROM texlive/texlive:latest

# Évite les questions interactives pendant apt
ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=fr_FR.UTF-8
ENV LC_ALL=fr_FR.UTF-8

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
    && echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen \
    && locale-gen \
    && printf 'LANG=fr_FR.UTF-8\nLC_ALL=fr_FR.UTF-8\n' > /etc/default/locale \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# ── 2. Politique ImageMagick (autorise PDF) ──────────────────
RUN sed -i 's/rights="none" pattern="PDF"/rights="read|write" pattern="PDF"/' \
    /etc/ImageMagick-6/policy.xml || true

# ── 3. Répertoires de travail ────────────────────────────────
RUN mkdir -p \
    /root/.AMC.d \
    /amc/projets \
    /amc/scan \
    /amc/controles \
    /texmf-local/nQcm

# ── 4. Entrypoint ────────────────────────────────────────────
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

WORKDIR /amc/projets
ENTRYPOINT ["/entrypoint.sh"]
CMD ["auto-multiple-choice", "gui"]
