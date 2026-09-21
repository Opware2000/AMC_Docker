# Journal des modifications

Toutes les modifications notables de ce projet sont consignées ici.

Format inspiré de [Keep a Changelog](https://keepachangelog.com/fr/1.1.0/),
versionnage [SemVer](https://semver.org/lang/fr/).

## [Unreleased]

## [3.0.0] — 2026-09-21

### Migration depuis la 2.0.0

Le passage à la 3.0.0 demande quelques étapes (client d'affichage Xpra,
reconstruction de l'image, mise à jour des volumes). Guide dédié :
**[`docs/migration-2-to-3.md`](docs/migration-2-to-3.md)**.

### Ajouté

- **Interface web** (navigateur) : le même AMC servi par
  [amc-webapp](https://gitlab.com/auto-multiple-choice/amc-webapp), via le
  service `amc-web` (profil Docker `webapp`, port 8080), construit par-dessus
  l'image de base (Flask + gunicorn).
- **GUI web repensée** (overlay `webapp/overrides/`) :
  - Material Design (palette Indigo, Roboto, élévations, app bar, drawer,
    champs « filled », chips, snackbars, ripple) ;
  - **thème sombre** commutable, préférence mémorisée ;
  - **rail de navigation** + **stepper** de progression ;
  - **FAB** contextuel selon l'écran ;
  - **notifications**, **erreurs visibles** (bloc + « Réessayer »), garde-fou
    sur la source non enregistrée, annulation des envois de fichiers ;
  - écrans retravaillés : **Scans** (barre d'outils, 3 volets, rapport en
    cartes), **pages en échec** (comparateur avant/après au curseur),
    **Notation / Association** (bascule de vue, filtres de statut, indice de
    correspondance), **Configuration** (cartes + curseurs), **Projets**
    (recherche, actions au survol, création en cartes de point de départ).
- **Internationalisation FR/EN** des chaînes de l'overlay (gettext, catalogues
  d'extension fusionnés au build) — `webapp/i18n/`.
- **Lanceurs séparés** : `launch-gtk.sh` (bureau/Xpra), `launch-web.sh`
  (navigateur), `stop-web.sh` (arrêt), `launch.sh` (alias de compatibilité).
- **Applications macOS** : `create-app.sh [gtk|web]` et `create-app-web.sh`
  (« Auto Multiple Choice.app » / « Auto Multiple Choice Web.app »).
- **Volumes à la racine** `LISTES`, `SCAN`, `SUJETS`, `QCM` (signets AMC).
- Mise à jour automatique de l'image quand les fichiers de build changent.

### Modifié

- Affichage : passage à **Xpra** (fenêtre native Mac, sans X11 côté Mac) ;
  fin de l'ère VNC/XQuartz.
- Base d'image : **TeX Live 2026 complet** (`texlive/texlive`, arm64).
- AMC depuis le **PPA officiel « test »** (AMC 1.7.0), dépôt épinglé.

### Corrigé

- **nQcm** : alias `nQcm.sty` ↔ `nQCM.sty` (le nom de fichier est sensible à la
  casse sous Linux, contrairement à macOS) — `\usepackage{nQcm}` fonctionne.
- Interface web : balise `<label>` mal fermée, flash d'erreur jamais déclenché,
  propriété `whitespace` invalide, viewport responsive, `lang` dynamique.
- Barre supérieure de l'interface web : hauteur constante (elle pouvait être
  compressée par le contenu selon l'écran).
- Icône de l'application : source GitLab mise à jour (rendu ImageMagick).

### Supprimé

- `lucide-icons.sty` embarqué (le paquet TeX Live est utilisé).

## [2.0.0] — 2026-04-19

### Ajouté

- **Pont Mac-bridge** : ouvrir les fichiers depuis AMC dans les applications
  Mac (TextEdit, Preview, Finder, LibreOffice, Numbers…).
- **Stub LibreOffice** (`ssconvert` + pont HTTP) et modules Perl associés.
- Prise en charge des **locales françaises** et des notifications de bureau.
- **Script de création d'application macOS** pour le Dock.
- Documentation Apple Silicon ; `docker-compose` adapté à Mac.

### Modifié

- Base d'image passée à `texlive/texlive`.
- Affichage : VNC, puis XQuartz (X11) avec pont Mac.
- Réglages d'affichage X11 (IPv4, `nolisten_tcp`, géométrie).

## [1.0.0] — 2025-11-20

### Ajouté

- Première version : **conteneur Docker pour Auto-Multiple-Choice**
  (Dockerfile, `docker-compose`, script de lancement, premier README),
  `xpdf`, fichier `.env` d'exemple.

[Unreleased]: https://github.com/Opware2000/AMC_Docker/compare/3.0.0...HEAD
[3.0.0]: https://github.com/Opware2000/AMC_Docker/compare/2.0.0...3.0.0
[2.0.0]: https://github.com/Opware2000/AMC_Docker/compare/1.0.0...2.0.0
[1.0.0]: https://github.com/Opware2000/AMC_Docker/releases/tag/1.0.0
