# AMC Docker — Apple Silicon (M1/M2/M3/M4)

Configuration Docker pour **Auto-Multiple-Choice** sur Mac Apple Silicon avec :
- Classe LaTeX `nQCM` intégrée automatiquement
- `texlive/texlive` (TeX Live upstream complet, arm64)
- Accès aux dossiers Dropbox CONTROLES et SCAN
- Affichage distant natif via **Xpra** (fenêtre Mac, pas d'émulation)
- Ouvrir les fichiers depuis AMC directement dans les apps Mac (TextEdit, Preview, Finder…)

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
├── docker-compose.yml          # Volumes et configuration (non versionné)
├── docker-compose.yaml.example # Template à copier/adapter
├── launch.sh                   # Lanceur Mac : vérifie Docker, pont HTTP, démarre le conteneur, attache Xpra
├── create-app.sh               # Crée « Auto Multiple Choice.app » pour le Dock
├── libreoffice-stub.sh         # Stub libreoffice (ssconvert + pont HTTP)
├── logs/                       # Logs Docker (gitignoré)
└── README.md                   # Ce fichier
```

### Volumes montés dans le conteneur

| Chemin sur le Mac             | Chemin dans Docker | Usage                            |
| ----------------------------- | ------------------ | -------------------------------- |
| `~/workspaces/Latex/nQcm`     | `/nqcm`            | Classe LaTeX nQCM (lecture seule)|
| `Dropbox/COURS/CONTROLES/SCAN`| `/amc/scan`        | Scans des copies                 |
| `Dropbox/COURS/CONTROLES`     | `/amc/controles`   | Sujets et données                |
| Volume Docker `amc-data`      | `/root/.AMC.d`     | Configuration et projets AMC     |

> Le fichier `docker-compose.yml` (gitignored) contient vos chemins personnels.
> Pour une autre machine, copiez `docker-compose.yaml.example` et adaptez les chemins.

---

## Première utilisation

### 1. Rendre les scripts exécutables

```bash
chmod +x launch.sh entrypoint.sh
```

### 2. Lancer AMC

```bash
./launch.sh
```

Le script `launch.sh` fait tout automatiquement :

1. Vérifie que Docker Desktop est lancé
2. Construit l'image `amc-nqcm:latest` au premier lancement
   (comptez **5 à 15 minutes** — TeX Live est pré-installé dans l'image de base)
3. Démarre un **pont Mac-bridge** sur le port 6081 (pour ouvrir les fichiers dans les apps Mac)
4. Lance le conteneur avec Xvfb (framebuffer X11) + Xpra (encapsule X11 → TCP:14500)
5. Attend que Xpra soit prêt, puis attache le client Mac natif
6. La fenêtre AMC s'ouvre comme une application Mac normale

Pour lancer plus tard, un simple `./launch.sh` suffit — l'image existant déjà, le démarrage prend quelques secondes.

### 3. Arrêter AMC

Fermez la fenêtre AMC ou faites `Ctrl+C` dans le Terminal — le script arrête proprement le conteneur et le pont.

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

C'est le pont HTTP du `launch.sh` qui transporte la demande. Les conversions de fichiers
(libreoffice → PDF) restent dans le conteneur via `ssconvert`.

---

## Ce qui est configuré automatiquement au démarrage

À chaque lancement, `entrypoint.sh` effectue :

- **Classe nQCM** — copiée dans `TEXMFLOCAL` et `mktexlsr` relancé
- **GTK3** — scrollbars toujours visibles, double-tap tolérant, signets pour `/amc/controles` et `/amc/scan`
- **Symlink projets** — `/root/MC-Projects` pointe vers `/amc/controles`
- **Xpra** — serveur X virtuel, clavier français / Apple

---

## Projets AMC dans Docker

AMC stocke ses projets dans `/root/.AMC.d` (volume Docker persistant `amc-data`).

Pour accéder à vos fichiers depuis AMC :
- **Scans** → naviguer vers `/amc/scan`
- **Sujets LaTeX** → naviguer vers `/amc/controles`
- **Signets GTK** → accès rapide à ces dossiers depuis la barre latérale des dialogues Ouvrir/Enregistrer

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

Le serveur Xpra met ~5 s à démarrer. `launch.sh` attend jusqu'à 30 s.
Si le délai est dépassé, lancez `docker compose logs` pour voir le message d'erreur.

### La classe nQCM n'est pas trouvée par LaTeX

```bash
# Vérifiez que le chemin dans docker-compose.yml est correct :
ls ~/workspaces/Latex/nQcm

# Vérifiez dans le conteneur :
docker compose run --entrypoint bash amc \
  -c "kpsewhich nQCM.cls 2>/dev/null || echo 'non trouvé'"
```

### Reconstruire l'image (après mise à jour)

```bash
docker compose build --no-cache
```

### Accéder au shell du conteneur (sans lancer AMC)

```bash
docker compose run --entrypoint bash amc
```

---

## Mettre à jour la classe nQCM

La classe nQCM est montée en lecture seule depuis votre Mac. Toute modification
dans `~/workspaces/Latex/nQcm` sera prise en compte **au prochain lancement**
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

## Créer une icône AMC dans le Dock

Pour lancer AMC comme n'importe quelle application macOS, sans passer par le Terminal :

### 1. Générer l'application

```bash
chmod +x create-app.sh
./create-app.sh
```

Ce script crée `Auto Multiple Choice.app` dans `~/Applications/` et ouvre
automatiquement le dossier pour vous. Il télécharge l'icône officielle d'AMC
si la connexion internet est disponible.

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

L'application contient le chemin absolu vers `launch.sh`. Si vous déplacez
le dossier `amc-docker`, relancez simplement `./create-app.sh` pour mettre
à jour l'application.

---

## Commandes utiles

```bash
# Lancer AMC
./launch.sh

# Shell dans le conteneur (pour déboguer)
docker compose run --entrypoint bash amc

# Voir les logs du dernier lancement
docker compose logs

# Arrêter le conteneur
docker compose down

# Supprimer les projets AMC stockés dans Docker (irréversible)
docker volume rm amc-docker_amc-data

# Vérifier la classe nQCM dans le conteneur
docker compose run --entrypoint bash amc -c "kpsewhich -all nQCM.cls 2>/dev/null || echo 'non trouvé'"

# Reconstruire l'image
docker compose build --no-cache
```