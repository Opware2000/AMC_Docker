# Surcharges de la GUI AMC webapp

Ce dossier permet de **surcharger** des fichiers du serveur
[amc-webapp](https://gitlab.com/auto-multiple-choice/amc-webapp) sans forker
le dépôt.

Le contenu de `overrides/` est copié dans l'image **après** le clone, par
`Dockerfile.webapp` :

```
COPY webapp/overrides/ /amc-web/
```

Il suffit donc de reproduire l'arborescence cible sous `overrides/`. Tout
fichier présent ici **écrase** celui du serveur d'origine.

Exemples :

```
overrides/server/templates/index.html
overrides/server/templates/projects_list.html
overrides/server/static/amc.css
overrides/server/static/amc.js
```

## Ordre de construction

1. clone de `amc-webapp` → `/amc-web/`
2. copie de `overrides/` par-dessus
3. `make` (traductions, ACE, icônes)
4. `flask digest compile`

> **Ne surchargez pas** les fichiers générés par `make` :
> `server/static/icons.css`, `server/ace/mode-amc_txt.js` et les
> `messages.mo` seraient écrasés par la construction.
> En revanche, surcharger un *template* suffit : `make icons` régénère
> `icons.css` à partir des templates.

## Reconstruire

Toute modification sous `overrides/` nécessite de reconstruire l'image :

```bash
docker compose --profile webapp up -d --build amc-web
```

## Itérer sans rebuild

Ajoutez temporairement le bind mount suivant au service `amc-web` de
`docker-compose.yml` :

```yaml
    volumes:
      - ./webapp/overrides/server:/amc-web/server
```

puis redémarrez le conteneur après chaque édition (gunicorn met les
templates en cache) :

```bash
docker compose --profile webapp restart amc-web
```
