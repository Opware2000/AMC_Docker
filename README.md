# AMC Docker — Apple Silicon (M1/M2/M3/M4)

Configuration Docker pour **Auto-Multiple-Choice** sur Mac Apple Silicon avec :
- Classe LaTeX `nQCM` intégrée automatiquement
- `texlive/texlive` — **TeX Live 2026 complet** (upstream, arm64), avec tous les
  paquets CTAN : `simplekv`, `lucide-icons`, `tabularray`, `tcolorbox`, etc.
- **AMC 1.7.0** — dernières corrections issues du **PPA officiel « test »**
  d'Alexis Bienvenüe, auteur d'AMC
- Accès à vos dossiers de travail (projets, listes, scans, sujets) via des volumes
- Affichage distant natif via **Xpra** (fenêtre Mac, pas d'émulation)
- Ouvrir les fichiers depuis AMC directement dans les apps Mac (TextEdit, Preview, Finder…)
- Alternative **navigateur** : le même AMC servi par [amc-webapp](https://gitlab.com/auto-multiple-choice/amc-webapp) (profil Docker `webapp`), avec une GUI **repensée** — Material Design, thème clair/sombre, stepper, FAB, notifications

---

## Prérequis

### 1. Docker Desktop

Téléchargez et installez [Docker Desktop pour Mac](https://www.docker.com/products/docker-desktop/) (version Apple Silicon).

### 2. Xpra (client Mac)

AMC est une application **GTK3/X11** — elle a besoin d'un serveur X pour afficher son interface.
Dans le conteneur, **Xvfb** (X virtual framebuffer) fournit cet affichage, et **Xpra** encapsule
le flux X11 dans une connexion TCP. Sur le Mac, le client Xpra décode ce flux en **fenêtre native**
(sans aucun X11 côté Mac).

```
┌─ Conteneur Docker ──────────────────────────────┐
│  AMC (GTK3) → X11 → Xvfb → Xpra server → TCP:14500 │
└──────────────────────────────────────────────────┘
                        ↕
┌─ Mac ────────────────────────────────────────────┐
│  Xpra client (fenêtre native, pas de X11)           │
└──────────────────────────────────────────────────┘
```

**Côté Mac, seul le client Xpra est nécessaire.**

```bash
brew install --cask xpra
```

> Avantage de Xpra vs XQuartz : pas de serveur X à installer sur le Mac, fenêtre native
> (pas d'émulation X11), meilleur clavier français et trackpad.
> Tout le X11 reste confiné dans le conteneur.

---

## Structure des fichiers

```
amc-docker/
├── .dockerignore               # Fichiers ignorés par Docker
├── Dockerfile                  # Image texlive/texlive + AMC + Xpra (arm64)
├── entrypoint.sh               # Installe nQCM, configure GTK, démarre xpra:14500
├── Dockerfile.webapp           # Couche serveur web (Flask amc-webapp + gunicorn)
├── entrypoint-webapp.sh        # Installe nQCM puis lance le serveur web
├── webapp/                     # Surcharges de la GUI du serveur web (Material Design)
├── docker-compose.yml          # Volumes et configuration (non versionné)
├── docker-compose.yaml.example # Template à copier/adapter
├── launch-gtk.sh               # Lanceur GTK : Docker, pont HTTP, conteneur, attache Xpra
├── launch-web.sh               # Lanceur web : démarre amc-web et ouvre localhost:8080
├── stop-web.sh                 # Arrête l'interface web (conteneur amc-web)
├── launch.sh                   # Alias de compatibilité → launch-gtk.sh
├── create-app.sh               # Crée l'app du Dock (gtk par défaut, web en argument)
├── create-app-web.sh           # Raccourci : crée « Auto Multiple Choice Web.app »
├── libreoffice-stub.sh         # Stub libreoffice (ssconvert + pont HTTP)
├── logs/                       # Logs Docker (gitignoré)
├── CHANGELOG.md                # Journal des versions
└── README.md                   # Ce fichier
```

### Volumes montés dans le conteneur

| Chemin sur le Mac                    | Chemin dans Docker | Usage                             |
| ------------------------------------ | ------------------ | --------------------------------- |
| `~/chemin/vers/nQcm`                 | `/nqcm`            | Classe LaTeX nQCM (lecture seule) |
| `/chemin/vers/CONTROLES`             | `/amc/controles`   | Sujets et données                 |
| `/chemin/vers/CONTROLES/LISTES`      | `/LISTES`          | Listes des élèves                 |
| `/chemin/vers/CONTROLES/SCAN`        | `/SCAN`            | Scans des copies                  |
| `/chemin/vers/CONTROLES/SUJETS`      | `/SUJETS`          | Sujets d'évaluation               |
| `/chemin/vers/QCM`                   | `/QCM`             | Dépôt QCM                         |
| `/chemin/vers/CONTROLES/SCAN`        | `/amc/scan`        | Alias historique de `/SCAN`       |
| Volume Docker `amc-data`             | `/root/.AMC.d`     | Configuration et projets AMC      |

> Les dossiers `LISTES`, `SCAN`, `SUJETS` et `QCM` sont montés **directement
> à la racine** du conteneur : ils apparaissent comme signets dans les dialogues
> Ouvrir/Enregistrer d'AMC (voir `entrypoint.sh`). Toute modification sur le Mac
> est visible **immédiatement** dans le conteneur, et inversement.

> Le fichier `docker-compose.yml` (gitignored) contient vos chemins personnels.
> Pour une autre machine, copiez `docker-compose.yaml.example` et adaptez les chemins.

### Personnalisation des chemins

Tous les chemins sont définis dans **un seul fichier** : `docker-compose.yml`.
Créez-le une fois à partir du modèle, puis adaptez les volumes :

```bash
cp docker-compose.yaml.example docker-compose.yml
```

```yaml
volumes:
  - /votre/chemin/vers/nQcm:/nqcm:ro
  - /votre/chemin/vers/CONTROLES:/amc/controles
  - /votre/chemin/vers/CONTROLES/LISTES:/LISTES
  - /votre/chemin/vers/CONTROLES/SCAN:/SCAN
  - /votre/chemin/vers/CONTROLES/SUJETS:/SUJETS
  - /votre/chemin/vers/QCM:/QCM
```

> `docker-compose.yml` est **gitignoré** : vos chemins réels ne sont jamais
> versionnés. `launch-gtk.sh` lit ces volumes via `docker compose config` — le pont
> Mac-bridge pointe donc automatiquement vers les mêmes dossiers, sans aucun
> chemin en dur dans le script.

---

## Première utilisation

### 1. Rendre les scripts exécutables

```bash
chmod +x launch.sh launch-gtk.sh launch-web.sh entrypoint.sh
```

### 2. Lancer AMC (interface GTK)

```bash
./launch-gtk.sh        # (ou ./launch.sh, alias de compatibilité)
```

Le script `launch-gtk.sh` fait tout automatiquement :

1. Vérifie que Docker Desktop est lancé
2. Construit **ou reconstruit** l'image `amc-nqcm:latest` :
   - au premier lancement (**~3 Go à télécharger** — l'image de base contient déjà TeX Live 2026 complet) ;
   - ensuite **uniquement si** `Dockerfile`, `entrypoint.sh`, `libreoffice-stub.sh` ou `.dockerignore`
     ont changé (empreinte `amc.build.hash` comparée à l'image). Le build est alors quasi instantané
     grâce au cache, seul le dernier étage étant régénéré.
3. Démarre un **pont Mac-bridge** sur le port 6081 (pour ouvrir les fichiers dans les apps Mac)
4. Lance le conteneur avec Xvfb (framebuffer X11) + Xpra (encapsule X11 → TCP:14500)
5. Attend que Xpra soit prêt, puis attache le client Mac natif
6. La fenêtre AMC s'ouvre comme une application Mac normale

Pour lancer plus tard, un simple `./launch-gtk.sh` suffit — l'image existant déjà, le démarrage prend quelques secondes.

### 2 bis. Lancer l'interface web (navigateur)

```bash
./launch-web.sh
```

Construit l'image de base si nécessaire, démarre `amc-web` et ouvre
<http://localhost:8080>. Pour l'arrêter : `./stop-web.sh`.
Détails dans « Alternative navigateur » plus bas.

Les deux interfaces peuvent tourner **en même temps** (ports 14500 et 8080
distincts), mais évitez d'ouvrir le **même projet** dans les deux : elles
partagent la configuration AMC et le dossier de projets (verrous, caches).

### 3. Arrêter AMC

- GTK : fermez la fenêtre AMC ou faites `Ctrl+C` dans le Terminal.
- Web : `./stop-web.sh` (ou `docker compose --profile webapp stop amc-web`).

---

## Ouvrir des fichiers Mac depuis AMC

Lancer un éditeur depuis AMC (« Ouvrir le sujet », « Ouvrir le PDF »…) ouvre en réalité l'application Mac native :

| Commande appelée par AMC      | Application Mac ouverte |
| ----------------------------- | ----------------------- |
| `texmaker`                    | TexMaker (si installé)  |
| `gnome-text-editor`          | TextEdit                |
| `papers` / `eog`             | Preview                 |
| `nautilus`                    | Finder                  |
| `libreoffice`                 | LibreOffice             |
| `gnumeric`                    | Numbers                 |

C'est le pont HTTP du `launch-gtk.sh` qui transporte la demande. Les conversions de fichiers
(libreoffice → PDF) restent dans le conteneur via `ssconvert`.

---

## Ce qui est configuré automatiquement au démarrage

À chaque lancement, `entrypoint.sh` effectue :

- **Classe nQCM** — copiée dans `TEXMFLOCAL`, `mktexlsr` relancé, et un alias
  `nQcm.sty` ↔ `nQCM.sty` créé (le nom de fichier est **sensible à la casse**
  sous Linux, contrairement à macOS)
- **GTK3** — scrollbars toujours visibles, double-tap tolérant, signets pour `/amc/controles`, `/LISTES`, `/SCAN`, `/SUJETS` et `/QCM`
- **Symlink projets** — `/root/MC-Projects` pointe vers `/amc/controles`
- **Xpra** — serveur X virtuel, clavier français / Apple

---

## Version d'Auto-Multiple-Choice (PPA « test »)

L'image n'utilise **pas** le paquet AMC de Debian, mais le **PPA officiel
« test »** d'Alexis Bienvenüe, auteur d'AMC :

- Dépôt : `ppa:alexis.bienvenue/test`
- Série Ubuntu utilisée : **stonking** (binaires Ubuntu 26.10)
- Version embarquée : `1.7.0+git20260914164232-1~stonking1`

> **Pourquoi *stonking* ?** La base Debian forky et les binaires Ubuntu
> *stonking* partagent la même ABI OpenCV (4.10) — les séries *noble*/*jammy*
> réclament OpenCV 4.6, absent. Le dépôt est épinglé : aucun autre paquet
> Ubuntu n'entre dans l'image.

Vérifier la version installée :

```bash
docker compose run --rm --entrypoint bash amc \
  -c "dpkg -l auto-multiple-choice | tail -1"
```

Changer de série Ubuntu (seulement si *stonking* n'est plus publiée, **en
vérifiant que la série cible embarque bien OpenCV 4.10**) :

```bash
docker compose build --build-arg AMC_PPA_SUITE=resolute
```

---

## Projets AMC dans Docker

AMC stocke ses projets dans `/root/.AMC.d` (volume Docker persistant `amc-data`).

Pour accéder à vos fichiers depuis AMC :
- **Signets GTK** → barre latérale des dialogues Ouvrir/Enregistrer : `Contrôles`,
  `LISTES`, `SCAN`, `SUJETS`, `QCM`
- **Scans** → `/SCAN` (alias historique `/amc/scan`)
- **Listes / Sujets** → `/LISTES`, `/SUJETS`
- **Projets complets** → `/amc/controles`

---

## Alternative navigateur (AMC webapp)

En plus de l'interface GTK, le même AMC peut être utilisé **dans le navigateur**
grâce au serveur officiel [amc-webapp](https://gitlab.com/auto-multiple-choice/amc-webapp).
La couche web est construite **par-dessus l'image existante** (`amc-nqcm:latest`) :
même AMC, même TeX Live, même classe nQCM — seuls Flask et gunicorn sont ajoutés.

```bash
# Lanceur dédié (construit l'image de base si besoin, démarre, ouvre le navigateur)
./launch-web.sh

# — ou, à la main —
docker compose build amc                                  # image de base (une seule fois)
docker compose --profile webapp up -d --build amc-web     # serveur web
# puis http://localhost:8080
```

Le service `amc-web` vit dans le même `docker-compose.yml`, sous le profil
`webapp` : `./launch-gtk.sh` (profil par défaut) ne le lance donc jamais. Il partage
avec la GUI les **projets** (`CONTROLES` → `/amc/controles`, via
`AMC_PROJECTSDIR`), la **configuration AMC** (volume `amc-data` → `/root/.AMC.d`)
et le dossier nQCM (`/nqcm`).

Pour **personnaliser la GUI** (templates HTML, CSS, JS), déposez vos fichiers
dans `webapp/overrides/` en reproduisant l'arborescence cible (`/amc-web/`) :
ils écraseront ceux du serveur au moment du build. Détails dans
`webapp/README.md`.

### Interface web personnalisée

La GUI du serveur web est **repensée** dans `webapp/overrides/` : Material
Design (thème **clair/sombre**), rail + **stepper** de progression, **FAB**
contextuel, **notifications**, et écrans retravaillés (Scans, pages en échec
avec comparateur avant/après, Notation/Association, Configuration, Projets).
Les chaînes ajoutées sont **traduites FR/EN** (gettext).

Détail complet dans [`CHANGELOG.md`](CHANGELOG.md) et `webapp/README.md`.

Arrêter le serveur web :

```bash
./stop-web.sh
# ou : docker compose --profile webapp stop amc-web
```

> **Mono-utilisateur.** Le serveur n'a **aucune authentification** : il est
> destiné à `localhost`. Pour un accès distant, placez-le derrière un
> reverse-proxy avec authentification (voir la doc officielle pour le mode
> multi-utilisateurs ; l'isolation landrun nécessite un noyau Linux ≥ 6.7).

---

## Dépannage

### La fenêtre AMC n'apparaît pas

```bash
# 1. Vérifiez que Xpra est installé sur le Mac
ls /Applications/Xpra.app

# 2. Vérifiez les logs du conteneur
docker compose logs

# 3. Attachez manuellement le client Xpra
/Applications/Xpra.app/Contents/MacOS/Xpra attach tcp://127.0.0.1:14500/
```

### Erreur "xpra is ready" attendue mais absente des logs

Le serveur Xpra met ~5 s à démarrer. `launch-gtk.sh` attend jusqu'à 30 s.
Si le délai est dépassé, lancez `docker compose logs` pour voir le message d'erreur.

### La classe nQCM n'est pas trouvée par LaTeX

Le paquet s'appelle **`nQCM.sty`** (extension `.sty`, pas `.cls`). Sous Linux
le nom de fichier est **sensible à la casse** : `\usepackage{nQCM}` est
l'orthographe exacte. Un alias `nQcm.sty` est créé automatiquement au
démarrage pour les documents qui écrivent `\usepackage{nQcm}` (voir
« Ce qui est configuré automatiquement »).

```bash
# Vérifiez que le chemin dans docker-compose.yml est correct :
ls ~/chemin/vers/nQcm

# Vérifiez dans le conteneur (les deux orthographes doivent répondre) :
docker compose run --entrypoint bash amc \
  -c "kpsewhich nQCM.sty nQcm.sty"
```

### Reconstruire l'image (après mise à jour)

```bash
docker compose build --no-cache
```

### Un paquet LaTeX manque encore

L'image embarque **TeX Live 2026 complet** : tous les paquets CTAN sont présents
(inclus `simplekv`, `lucide-icons`, `tabularray`, `tcolorbox`…). Pour vérifier :

```bash
docker compose run --rm --entrypoint bash amc \
  -c "kpsewhich lucide-icons.sty simplekv.sty"
```

Si un paquet est réellement absent (rare), `tlmgr` fonctionne (contrairement à
l'ancienne base Debian 2022) :

```bash
docker compose run --rm --entrypoint bash amc -c "tlmgr install <paquet>"
```

### Accéder au shell du conteneur (sans lancer AMC)

```bash
docker compose run --entrypoint bash amc
```

---

## Mettre à jour la classe nQCM

La classe nQCM est montée en lecture seule depuis votre Mac. Toute modification
dans `~/chemin/vers/nQcm` sera prise en compte **au prochain lancement**
d'AMC (l'entrypoint copie les fichiers dans TEXMFLOCAL et relance `mktexlsr`).

---

## Variables d'environnement

Le conteneur est configuré en `fr_FR.UTF-8` — l'image `texlive/texlive` filtre les locales non‑anglaises, donc l'entrypoint force la réinstallation des locales françaises et du paquet `auto-multiple-choice-common` pour les traductions.

---

## Suivi de version de l'image

Le Dockerfile expose des **labels OCI**. Pour les valoriser au build :

```bash
docker compose build \
  --build-arg AMC_VERSION=1.2.0 \
  --build-arg AMC_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --build-arg AMC_VCS_REF="$(git rev-parse --short HEAD)"
```

Inspectez ensuite les labels :

```bash
docker image inspect amc-nqcm:latest \
  --format '{{ json .Config.Labels }}' | jq
```

---

## Historique des versions

Les nouveautés et correctifs de chaque version sont dans
[`CHANGELOG.md`](CHANGELOG.md). Guide de passage depuis la 2.0.0 :
[`docs/migration-2-to-3.md`](docs/migration-2-to-3.md).

---

## Créer une icône AMC dans le Dock

Pour lancer AMC comme n'importe quelle application macOS, sans passer par le Terminal :

### 1. Générer l'application

```bash
chmod +x create-app.sh create-app-web.sh

./create-app.sh            # « Auto Multiple Choice.app »      → interface GTK
./create-app-web.sh        # « Auto Multiple Choice Web.app »  → interface web
# (équivalent : ./create-app.sh web)
```

Ces scripts créent les applications dans `~/Applications/` et ouvrent
automatiquement le dossier pour vous. Ils téléchargent l'icône officielle d'AMC
si la connexion internet est disponible. `AMC_NO_OPEN=1` évite d'ouvrir le
dossier (utile en automatisation).

### 2. Ajouter au Dock

Glissez `Auto Multiple Choice` depuis la fenêtre Finder qui s'est ouverte
vers le Dock (à droite de la séparation, avec les applications).

### 3. Utilisation

Un clic sur l'icône dans le Dock ouvre un Terminal dédié et lance AMC.
Vous voyez les messages de démarrage (utile pour diagnostiquer un problème).

> **Note** : si macOS affiche « application non vérifiée » au premier lancement,
> faites **Ctrl + clic** sur l'icône > **Ouvrir** > **Ouvrir** pour la débloquer.
> Cette fenêtre n'apparaît qu'une seule fois.

### Recréer l'application après un déplacement du dossier amc-docker

L'application contient le chemin absolu vers `launch-gtk.sh`. Si vous déplacez
le dossier `amc-docker`, relancez simplement `./create-app.sh` (et
`./create-app-web.sh` pour la version web) pour mettre à jour l'application.

---

## Commandes utiles

```bash
# Lancer AMC (interface GTK)
./launch-gtk.sh

# Lancer AMC (interface web)
./launch-web.sh

# Arrêter l'interface web
./stop-web.sh

# Shell dans le conteneur (pour déboguer)
docker compose run --entrypoint bash amc

# Voir les logs du dernier lancement
docker compose logs

# Arrêter le conteneur
docker compose down

# Supprimer les projets AMC stockés dans Docker (irréversible)
docker volume rm amc-docker_amc-data

# Vérifier la classe nQCM dans le conteneur
docker compose run --entrypoint bash amc -c "kpsewhich -all nQCM.sty nQcm.sty 2>/dev/null || echo 'non trouvé'"

# Reconstruire l'image
docker compose build --no-cache
```