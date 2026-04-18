# AMC Docker — Apple Silicon (M1/M2/M3/M4)

Configuration Docker pour **Auto-Multiple-Choice** sur Mac Apple Silicon avec :
- Classe LaTeX `nQCM` intégrée automatiquement
- `texlive-full`
- Accès aux dossiers Dropbox CONTROLES et SCAN
- Interface graphique via XQuartz

---

## Prérequis

### 1. Docker Desktop
Téléchargez et installez [Docker Desktop pour Mac](https://www.docker.com/products/docker-desktop/) (version Apple Silicon).

### 2. XQuartz
AMC utilise une interface graphique GTK qui nécessite un serveur X11.

```bash
# Option 1 : Homebrew
brew install --cask xquartz

# Option 2 : Téléchargement direct
# https://www.xquartz.org/
```

**Configuration obligatoire de XQuartz :**

1. Lancez XQuartz
2. Ouvrez **XQuartz > Réglages > Sécurité**
3. Cochez **☑ Autoriser les connexions depuis les clients réseau**
4. **Redémarrez XQuartz** (fermer et rouvrir l'application)

> ⚠️ Cette étape est indispensable. Sans elle, Docker ne peut pas
> afficher la fenêtre d'AMC.

---

## Structure des dossiers

```
amc-docker/
├── Dockerfile          # Image Debian + AMC + texlive-full
├── entrypoint.sh       # Installe nQCM et lance AMC
├── docker-compose.yml  # Configuration des volumes et de l'affichage
├── launch.sh           # Script de lancement simplifié
└── README.md           # Ce fichier
```

### Volumes montés dans le conteneur

| Chemin sur le Mac | Chemin dans Docker | Usage |
|---|---|---|
| `~/workspaces/Latex/nQcm` | `/nqcm` | Classe LaTeX nQCM (lecture seule) |
| `Dropbox/COURS/CONTROLES/SCAN` | `/amc/scan` | Scans des copies |
| `Dropbox/COURS/CONTROLES` | `/amc/controles` | Sujets et données |
| Volume Docker `amc-data` | `/root/.AMC.d` | Configuration et projets AMC |

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

La **première fois**, Docker va télécharger et construire l'image.  
`texlive-full` représente ~4 Go — comptez **20 à 40 minutes** selon votre connexion.  
Les fois suivantes, AMC se lance en quelques secondes.

---

## Projets AMC dans Docker

AMC stocke ses projets dans `/root/.AMC.d` (volume Docker persistant `amc-data`).

Pour accéder à vos sujets et scans depuis AMC :
- **Scans** : `/amc/scan` dans la boîte de dialogue d'AMC
- **Sujets LaTeX** : `/amc/controles` dans la boîte de dialogue d'AMC

---

## Dépannage

### La fenêtre AMC n'apparaît pas

```bash
# Vérifiez que XQuartz est lancé et que xhost est configuré :
xhost +127.0.0.1
xhost +localhost

# Vérifiez que le serveur X est accessible :
DISPLAY=:0 xdpyinfo | head -5
```

### Erreur "cannot open display"

```bash
# Dans XQuartz > Réglages > Sécurité :
# → cochez "Autoriser les connexions depuis les clients réseau"
# → redémarrez XQuartz
```

### La classe nQCM n'est pas trouvée

Vérifiez que le chemin dans `docker-compose.yml` correspond bien à votre installation :
```yaml
- /Users/nicolasogier/workspaces/Latex/nQcm:/nqcm:ro
```

Dans le conteneur, vérifiez :
```bash
docker run --rm -it amc-nqcm:latest bash
kpsewhich nQCM.cls    # ou le nom de votre fichier .cls
```

### Reconstruire l'image

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

# Voir les logs
docker compose logs

# Arrêter le conteneur
docker compose down

# Supprimer les données AMC (projets sauvegardés dans Docker)
docker volume rm amc-docker_amc-data

# Shell dans le conteneur (pour déboguer)
DISPLAY=host.docker.internal:0 docker compose run --entrypoint bash amc

# Vérifier la classe nQCM dans le conteneur
docker compose run --entrypoint bash amc -c "kpsewhich -all nQCM.cls 2>/dev/null || echo 'non trouvé'"
```
