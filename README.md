# Auto-Multiple-Choice avec noVNC

Configuration Docker pour exécuter AMC avec une interface graphique accessible via navigateur web.

## 📋 Prérequis

- Docker et Docker Compose installés
- macOS, Linux ou Windows avec Docker Desktop

## 🚀 Installation

### 1. Créer la structure des fichiers

```bash
mkdir amc-docker
cd amc-docker

# Créer les fichiers (Dockerfile, docker-compose.yml, start-amc.sh)
# Copier le contenu des artifacts fournis

# Créer les répertoires pour les volumes
mkdir -p amc-projects amc-config texmf/tex/latex
```

### 2. Configuration du mot de passe VNC

**IMPORTANT** : Changez le mot de passe par défaut !

Créez un fichier `.env` :

```bash
echo "VNC_PASSWORD=VotreMotDePasseSecurise" > .env
```

Ou exportez la variable :

```bash
export VNC_PASSWORD="VotreMotDePasseSecurise"
```

### 3. Construire et lancer

```bash
# Construire l'image
docker-compose build

# Lancer le conteneur
docker-compose up -d

# Voir les logs
docker-compose logs -f
```

## 🌐 Accès à l'interface

### Via le navigateur (recommandé)

Ouvrez : **http://localhost:6080/vnc.html**

- Cliquez sur "Connect"
- Entrez le mot de passe VNC configuré
- L'interface AMC s'affiche automatiquement

### Via un client VNC (optionnel)

- Hôte : `localhost:5900`
- Mot de passe : celui configuré dans `.env`

Clients VNC recommandés pour macOS :
- RealVNC Viewer
- TigerVNC
- Screen Sharing (intégré à macOS)

## 📁 Organisation des fichiers

```
amc-docker/
├── Dockerfile              # Image Docker
├── docker-compose.yml      # Configuration des services
├── start-amc.sh           # Script de démarrage
├── .env                   # Variables d'environnement (mot de passe)
├── amc-projects/          # Vos projets AMC (persistant)
├── amc-config/            # Configuration AMC (persistant)
└── texmf/                 # Packages LaTeX personnalisés
    └── tex/
        └── latex/         # Mettez vos .sty, .cls ici
```

## 🔧 Commandes utiles

```bash
# Démarrer
docker-compose up -d

# Arrêter
docker-compose down

# Redémarrer
docker-compose restart

# Voir les logs
docker-compose logs -f

# Ouvrir un terminal dans le conteneur
docker-compose exec amc bash

# Reconstruire après modification
docker-compose up -d --build
```

## ⚙️ Personnalisation

### Changer la résolution d'écran

Dans `docker-compose.yml`, modifiez :

```yaml
- VNC_RESOLUTION=1920x1080  # ou 1440x900, 1680x1050, etc.
```

### Ajouter des éditeurs LaTeX

Dans le `Dockerfile`, ajoutez avant le nettoyage :

```dockerfile
texmaker \
texstudio \
```

### Ajouter des packages LaTeX personnalisés

Placez vos fichiers `.sty` ou `.cls` dans le dossier `texmf/tex/latex/` :

```bash
# Exemple : ajouter un package custom
cp monpackage.sty texmf/tex/latex/

# Ou créer une structure pour plusieurs packages
mkdir -p texmf/tex/latex/monpackage
cp *.sty texmf/tex/latex/monpackage/
```

Les packages seront automatiquement disponibles dans AMC et Texmaker sans besoin de reconstruire l'image !

**Note** : Pour les packages CTAN standards, utilisez plutôt `tlmgr` dans le conteneur :

```bash
docker-compose exec amc bash
tlmgr install nomdupackage
```

### Désactiver le lancement automatique d'AMC

Dans `start-amc.sh`, commentez la ligne :

```bash
# auto-multiple-choice &
```

## 🐛 Résolution de problèmes

### Le port 6080 est déjà utilisé

Changez le port dans `docker-compose.yml` :

```yaml
ports:
  - "6081:6080"  # Utilisez 6081 au lieu de 6080
```

Puis accédez à : http://localhost:6081/vnc.html

### L'interface est lente

1. Augmentez les ressources allouées dans `docker-compose.yml`
2. Réduisez la résolution dans `VNC_RESOLUTION`
3. Fermez les applications inutilisées dans l'interface

### Impossible de se connecter

```bash
# Vérifiez que le conteneur tourne
docker-compose ps

# Vérifiez les logs
docker-compose logs amc

# Redémarrez
docker-compose restart
```

### Problème de permissions sur les fichiers

```bash
# Sur macOS/Linux, ajustez les permissions
sudo chown -R $(id -u):$(id -g) amc-projects amc-config
```

## 📚 Utilisation d'AMC

Une fois connecté via noVNC :

1. **Créer un nouveau projet** : Menu "Projet" → "Nouveau projet"
2. **Vos fichiers** sont dans `/home/amc/AMC-projects`
3. **Éditer LaTeX** : Lancez Texmaker depuis le menu ou via `texmaker` dans le terminal
4. **Importer des copies scannées** : utilisez le menu "Documents"
5. **Exporter les résultats** : Menu "Notation" → "Exporter"

### Outils disponibles

- **auto-multiple-choice** : Gestionnaire de QCM
- **texmaker** : Éditeur LaTeX complet avec coloration syntaxique
- **evince / xpdf** : Visualiseurs PDF
- **gedit / mousepad** : Éditeurs de texte simples

## 🔒 Sécurité

- **Ne jamais** exposer ce conteneur sur Internet sans VPN/reverse proxy
- Changez **toujours** le mot de passe VNC par défaut
- Les ports 5900 et 6080 doivent rester en local (localhost)

## 🤝 Contributions

Pour améliorer cette configuration, n'hésitez pas à :
- Ajouter des outils LaTeX supplémentaires
- Optimiser les performances
- Améliorer la sécurité

## 📝 Licence

AMC est sous licence GPL. Cette configuration Docker est fournie "as is".

---

**Bon travail avec vos QCM !** 📝✨