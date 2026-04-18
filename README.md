# AMC Docker — Apple Silicon (M1/M2/M3/M4)

Configuration Docker pour **Auto-Multiple-Choice** sur MacBook Air Apple Silicon avec :
- Classe LaTeX `nQCM` intégrée automatiquement
- `texlive-full`
- Accès aux dossiers Dropbox CONTROLES et SCAN
- Interface graphique via XQuartz
- Clavier Mac français (Apple AZERTY) et trackpad configurés

---

## Prérequis

### 1. Docker Desktop

Téléchargez et installez [Docker Desktop pour Mac](https://www.docker.com/products/docker-desktop/) (version Apple Silicon).

### 2. XQuartz

AMC utilise une interface graphique GTK qui nécessite un serveur X11.

```bash
# Via Homebrew (recommandé)
brew install --cask xquartz
```

Ou téléchargement direct sur [xquartz.org](https://www.xquartz.org/).

> ⚠️ Après l'installation, **déconnectez-vous et reconnectez-vous** à votre session macOS
> (ou redémarrez). XQuartz ne sera correctement initialisé qu'après cette étape.

---

## Configuration de XQuartz

C'est l'étape la plus importante — à faire **une seule fois** après l'installation.

Lancez XQuartz, puis ouvrez **XQuartz > Réglages** dans la barre de menus.

---

### Onglet « Sécurité »

| Réglage                                            | Valeur   | Pourquoi                                                           |
| -------------------------------------------------- | -------- | ------------------------------------------------------------------ |
| Autoriser les connexions depuis les clients réseau | ☑ Activé | **Indispensable** — permet à Docker de se connecter au serveur X11 |

> Sans ce réglage, AMC ne pourra jamais s'afficher depuis Docker.

---

### Onglet « Entrée »

| Réglage                                   | Valeur   | Pourquoi                                                                                                                 |
| ----------------------------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------ |
| Émuler une souris à 3 boutons             | ☑ Activé | Permet le **clic droit** (deux doigts sur le trackpad) et le clic du milieu (Option + clic) — indispensable sans souris  |
| Utiliser le réglage OSX de vitesse souris | ☑ Activé | Reprend la vitesse/accélération réglée dans les Préférences Système — sans ça le curseur est trop lent dans AMC          |
| Suivre le clavier système                 | ☑ Activé | Laisse XQuartz gérer la disposition clavier depuis macOS (en complément de notre configuration AZERTY dans le conteneur) |

---

### Après avoir modifié les réglages

**Quittez complètement XQuartz et relancez-le.** Les réglages de Sécurité et d'Entrée
ne sont pris en compte qu'au redémarrage de l'application.

```
XQuartz > Quitter X11   (ou Cmd+Q depuis la fenêtre XQuartz)
```

Puis relancez XQuartz depuis le Finder ou via `open -a XQuartz` dans le Terminal.

---

### Récapitulatif des gestes trackpad dans AMC

Une fois XQuartz configuré comme ci-dessus :

| Geste                         | Équivalent souris                |
| ----------------------------- | -------------------------------- |
| Tap un doigt                  | Clic gauche                      |
| Tap deux doigts               | Clic droit (menus contextuels)   |
| Option + clic                 | Clic du milieu                   |
| Glisser deux doigts           | Défilement vertical / horizontal |
| Tap deux doigts sur scrollbar | Aller directement à la position  |

---

## Structure des fichiers

```
amc-docker/
├── Dockerfile          # Image Debian + AMC + texlive-full
├── entrypoint.sh       # Installe nQCM, configure clavier et trackpad, lance AMC
├── docker-compose.yml  # Volumes et configuration de l'affichage
├── launch.sh           # Script de lancement (vérifie XQuartz, configure xhost)
└── README.md           # Ce fichier
```

### Volumes montés dans le conteneur

| Chemin sur le Mac              | Chemin dans Docker | Usage                             |
| ------------------------------ | ------------------ | --------------------------------- |
| `~/workspaces/Latex/nQcm`      | `/nqcm`            | Classe LaTeX nQCM (lecture seule) |
| `Dropbox/COURS/CONTROLES/SCAN` | `/amc/scan`        | Scans des copies                  |
| `Dropbox/COURS/CONTROLES`      | `/amc/controles`   | Sujets et données                 |
| Volume Docker `amc-data`       | `/root/.AMC.d`     | Configuration et projets AMC      |

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

La **première fois**, Docker télécharge et construit l'image.
`texlive-full` représente ~4 Go — comptez **20 à 40 minutes** selon votre connexion.
Les fois suivantes, AMC se lance en quelques secondes.

---

## Ce qui est configuré automatiquement au lancement

À chaque démarrage du conteneur, `entrypoint.sh` effectue automatiquement :

- **Classe nQCM** — copiée dans `TEXMFLOCAL` et `mktexlsr` relancé
- **Clavier** — `setxkbmap -model apple -layout fr -variant mac`
- **Pointeur** — accélération adaptée au trackpad (`xset m 2/1 4`)
- **GTK3** — scrollbars toujours visibles, double-tap tolérant, pas de drag accidentel

---

## Projets AMC dans Docker

AMC stocke ses projets dans `/root/.AMC.d` (volume Docker persistant `amc-data`).

Pour accéder à vos fichiers depuis AMC :
- **Scans** → naviguer vers `/amc/scan`
- **Sujets LaTeX** → naviguer vers `/amc/controles`

---

## Dépannage

### La fenêtre AMC n'apparaît pas

```bash
# 1. Vérifiez que XQuartz est lancé
open -a XQuartz

# 2. Autorisez les connexions
xhost +127.0.0.1
xhost +localhost

# 3. Testez la connexion X11
DISPLAY=:0 xdpyinfo | head -3
```

### Erreur "cannot open display"

Cause la plus fréquente : l'option **"Autoriser les connexions depuis les clients réseau"**
n'est pas cochée dans XQuartz > Réglages > Sécurité, ou XQuartz n'a pas été redémarré
après la modification.

### Le clic droit ne fonctionne pas

Vérifiez que **"Émuler une souris à 3 boutons"** est coché dans XQuartz > Réglages > Entrée,
puis redémarrez XQuartz.

### Le curseur est trop lent

Vérifiez que **"Utiliser le réglage OSX de vitesse souris"** est coché dans XQuartz > Réglages > Entrée.
Ajustez aussi la vitesse du trackpad dans Réglages Système macOS > Trackpad.

### La classe nQCM n'est pas trouvée par LaTeX

```bash
# Vérifiez que le chemin dans docker-compose.yml est correct :
ls /Users/nicolasogier/workspaces/Latex/nQcm

# Vérifiez dans le conteneur :
DISPLAY=host.docker.internal:0 docker compose run --entrypoint bash amc \
  -c "kpsewhich nQCM.cls 2>/dev/null || echo 'non trouvé'"
```

### Reconstruire l'image (après une mise à jour)

```bash
docker compose build --no-cache
```

### Accéder au shell du conteneur

```bash
DISPLAY=host.docker.internal:0 docker compose run --entrypoint bash amc
```

---

## Mettre à jour la classe nQCM

La classe nQCM est montée en lecture seule depuis votre Mac. Toute modification
dans `~/workspaces/Latex/nQcm` sera prise en compte **au prochain lancement** 
d'AMC (l'entrypoint copie les fichiers dans TEXMFLOCAL et relance `mktexlsr`).

---

## Commandes utiles

```bash
# Lancer AMC
./launch.sh

# Shell dans le conteneur (pour déboguer)
DISPLAY=host.docker.internal:0 docker compose run --entrypoint bash amc

# Voir les logs du dernier lancement
docker compose logs

# Arrêter le conteneur
docker compose down

# Supprimer les projets AMC stockés dans Docker (irréversible)
docker volume rm amc-docker_amc-data
# Vérifier la classe nQCM dans le conteneur
docker compose run --entrypoint bash amc -c "kpsewhich -all nQCM.cls 2>/dev/null || echo 'non trouvé'"
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
