# AMC Docker Container

Configuration Docker pour exécuter Auto-Multiple-Choice (AMC) dans un environnement Debian avec interface graphique VNC.

## Configuration

### Variables d'environnement

Le mot de passe VNC est configurable via une variable d'environnement :

- **VNC_PASSWORD** : Mot de passe pour la connexion VNC (défaut: `monpasswordsecret`)

### Utilisation

1. **Configuration initiale (optionnelle)** :
   ```bash
   # Copier le fichier d'exemple
   cp .env.example .env
   
   # Éditer le fichier .env pour personnaliser le mot de passe
   nano .env
   ```

2. **Démarrage du conteneur** :
   ```bash
   # Avec le fichier .env
   docker-compose up -d
   
   # Ou avec un mot de passe personnalisé directement
   VNC_PASSWORD=monmotdepasse docker-compose up -d
   ```

3. **Connexion VNC** :
   - Utiliser un client VNC (TigerVNC, RealVNC, TightVNC, etc.) : [https://remoteripple.com/download/](https://www.realvnc.com/en/connect/download/viewer/)
   - Se connecter à `localhost:5900`
   - Utiliser le mot de passe défini dans `VNC_PASSWORD`

4. **Arrêt du conteneur** :
   ```bash
   docker-compose down
   ```

## Structure des fichiers

- `Dockerfile` : Image Debian avec AMC et environnement graphique
- `docker-compose.yaml` : Configuration de composition avec liaison du dossier home
- `home/` : Dossier local lié au home du conteneur (`/root`)
- `.env.example` : Exemple de configuration des variables d'environnement

## Fonctionnalités

- Interface graphique X11 avec Openbox
- VNC server sur le port 5900
- Locale française configurée
- Persistance des données via le montage de volume
- Variables d'environnement configurables

## Notes

- Le dossier `home` est automatiquement créé s'il n'existe pas
- Toutes les données sauvegardées dans `/root` du conteneur seront disponibles dans `./home` local
- L'application AMC se lance automatiquement dans l'environnement VNC