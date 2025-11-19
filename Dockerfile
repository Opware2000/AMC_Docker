FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive \
    TZ=Europe/Paris \
    DISPLAY=:0 \
    LC_ALL=fr_FR.UTF-8 \
    LANG=fr_FR.UTF-8 \
    LANGUAGE=fr_FR.UTF-8 \
    VNC_RESOLUTION=1280x720 \
    VNC_PORT=5900 \
    NOVNC_PORT=6080

# Installation des dépendances et AMC
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    # Serveur X et VNC
    xvfb \
    x11vnc \
    # noVNC et websockify
    novnc \
    websockify \
    # Gestionnaire de fenêtres léger
    openbox \
    # Terminaux et outils
    xterm \
    # AMC et ses dépendances
    auto-multiple-choice \
    # Modules Perl supplémentaires pour AMC
    libopenoffice-oodoc-perl \
    # Visualiseur PDF
    xpdf \
    evince \
    # Visualiseur d'images
    eog \
    # Gestionnaire de fichiers
    pcmanfm \
    # Suite bureautique LibreOffice (calc pour les tableurs)
    libreoffice-calc \
    libreoffice-writer \
    # Éditeur de texte simple
    gedit \
    mousepad \
    # Éditeur LaTeX
    texmaker \
    # Utilitaires
    procps \
    net-tools \
    locales \
    && \
    # Configuration des locales
    sed -i -e 's/# \(fr_FR\.UTF-8 .*\)/\1/' /etc/locale.gen && \
    sed -i -e 's/# \(en_US\.UTF-8 .*\)/\1/' /etc/locale.gen && \
    locale-gen && \
    # Nettoyage
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Créer un utilisateur non-root
RUN useradd -m -s /bin/bash amc && \
    mkdir -p /home/amc/.config/AMC && \
    chown -R amc:amc /home/amc

# Copier le script de démarrage
COPY --chown=amc:amc start-amc.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/start-amc.sh

# Créer les répertoires de travail
RUN mkdir -p /home/amc/AMC-projects && \
    mkdir -p /home/amc/texmf/tex/latex && \
    chown -R amc:amc /home/amc/AMC-projects && \
    chown -R amc:amc /home/amc/texmf

# Configurer le TEXMFHOME pour utiliser les packages personnalisés
ENV TEXMFHOME=/home/amc/texmf

USER amc
WORKDIR /home/amc

EXPOSE 5900 6080

CMD ["/usr/local/bin/start-amc.sh"]