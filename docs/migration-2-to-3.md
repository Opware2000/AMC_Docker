# Migration de la 2.0.0 vers la 3.0.0

Le passage à la 3.0.0 change le **client d'affichage**, la **base d'image** et
certains **volumes**. Comptez quelques minutes, plus le temps de reconstruction
de l'image.

> En résumé : installez **Xpra** (XQuartz n'est plus utilisé), **reconstruisez**
> l'image, **mettez à jour** votre `docker-compose.yml`, puis relancez.

---

## 1. Client d'affichage : Xpra remplace XQuartz

La 2.0.0 utilisait VNC/XQuartz. La 3.0.0 utilise **Xpra** (fenêtre native, sans
serveur X côté Mac).

```bash
brew install --cask xpra
```

- XQuartz **n'est plus nécessaire** (vous pouvez le désinstaller).
- `launch-gtk.sh` démarre le serveur Xpra dans le conteneur (port **14500**) et
  attache la fenêtre native.
- Vérification : `ls /Applications/Xpra.app` doit exister.

## 2. Reconstruire l'image

La base est passée à **TeX Live 2026 complet** (`texlive/texlive`) et AMC vient
du **PPA officiel « test »**. Une image 2.x doit être reconstruite :

```bash
docker compose build --no-cache amc
```

> Le premier build télécharge plusieurs gigaoctets. Les suivants sont quasi
> instantanés grâce au cache (sauf si `Dockerfile`, `entrypoint.sh`,
> `libreoffice-stub.sh` ou `.dockerignore` changent).

## 3. Mettre à jour `docker-compose.yml`

Ce fichier **n'est pas versionné** (vos chemins personnels y sont). Reportez les
nouveaux volumes depuis `docker-compose.yaml.example` :

- `LISTES`, `SCAN`, `SUJETS`, `QCM` sont désormais montés **à la racine** du
  conteneur (ils apparaissent comme signets dans AMC) ;
- le volume nommé `amc-data` persiste la configuration AMC (`/root/.AMC.d`).

```bash
# Repartir de l'exemple puis remettre vos chemins :
cp docker-compose.yaml.example docker-compose.yml
# ... rééditez les chemins ...
docker compose config >/dev/null && echo "compose OK"
```

## 4. Relancer

```bash
./launch-gtk.sh     # ou ./launch.sh (alias de compatibilité)
```

Puis régénérez l'application du Dock : elle pointe désormais sur
`launch-gtk.sh` et non plus sur `launch.sh`.

```bash
./create-app.sh
```

## 5. nQcm

Vous n'avez **plus besoin de copier `nQCM.sty`** dans vos projets : un alias
`nQcm.sty` est créé automatiquement au démarrage du conteneur (le nom de fichier
est sensible à la casse sous Linux, contrairement à macOS).

- Forme correcte : `\usepackage{nQCM}`.
- `\usepackage{nQcm}` fonctionne aussi (alias).
- Vous pouvez supprimer les copies locales de `nQCM.sty` dans vos projets.

## 6. Interface web (optionnelle)

Nouvelle interface navigateur, sans rien à migrer :

```bash
./launch-web.sh     # → http://localhost:8080
./stop-web.sh       # arrêt
```

⚠️ Elle est **mono-utilisateur** (aucune authentification) : prévue pour
`localhost`. Pour un accès distant, placez-la derrière un reverse-proxy avec
authentification.

---

## En cas de problème

| Symptôme | Piste |
|---|---|
| La fenêtre AMC ne s'ouvre pas | Xpra installé ? `docker compose logs` ; attache manuelle : `xpra attach tcp://127.0.0.1:14500/` |
| `\usepackage{nQCM}` introuvable | `docker compose run --entrypoint bash amc -c "kpsewhich nQCM.sty nQcm.sty"` |
| Signets AMC absents | Vérifiez les volumes à la racine dans `docker-compose.yml` |
| Ancienne image réutilisée | `docker compose build --no-cache amc` |

Dépannage détaillé : voir le [README](../README.md#dépannage).
