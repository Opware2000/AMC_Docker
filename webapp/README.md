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

## Contenu actuel des surcharges

- `templates/index.html` — shell de l'application : rail de navigation,
  app bar, stepper, FAB, conteneurs de notifications et de progression
- `templates/tab_*.html` — écrans Scans (et « pages en échec »), Notation,
  Configuration, Source
- `templates/projects_list.html`, `project_new.html`, `assoc_sheets.html`,
  `manual_view.html`… — listes et vues détaillées
- `static/amc.css` — tokens de couleurs, thème **Material Design** (clair et
  sombre) et styles des écrans
- `static/amc.js` — comportements ajoutés : bascule de thème, stepper, FAB,
  notifications, blocs d'erreur, comparateur avant/après, filtres
  d'association, indice de correspondance, ripple, recherche de projets

## Thèmes

- Les couleurs passent par des variables CSS définies dans `:root` et
  redéfinies sous `[data-theme="dark"]` (sur `<html>`).
- La préférence est stockée dans `localStorage` (clé `amc-theme`) et appliquée
  par un petit script en `<head>` **avant le premier rendu** (pas de flash).
- La police **Roboto** est **hébergée localement** (aucune requête vers Google
  Fonts) ; en cas d'échec, une pile sans-serif système prend le relais.

## Polices

- `static/fonts.css` déclare `@font-face` et pointe vers
  `static/fonts/roboto-latin.woff2`.
- C'est la version **variable** de Roboto, sous-ensemble **latin**, qui couvre
  le français (accents, `œ`, `€`, `’`, `—`, `…`). Un seul fichier suffit donc
  pour toutes les graisses (100–900).
- La source est Google Fonts (`fonts.gstatic.com`, licence Apache 2.0).

Pour rafraîchir le fichier, récupérer l'URL du sous-ensemble latin (avec un
`User-Agent` de navigateur) puis télécharger :

```bash
curl -s -A "Mozilla/5.0 ... Chrome/124 Safari/537.36" \
  "https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" \
  | grep -A6 'U+0000-00FF' | grep -o 'https://[^)]*\.woff2' | head -1
# puis :
curl -s -o static/fonts/roboto-latin.woff2 "<l'URL obtenue>"
```

## Internationalisation

Les chaînes ajoutées par l'overlay sont traduites via **gettext**, sans
surcharger les catalogues amont :

- `webapp/i18n/extra-fr.po` et `extra-en.po` ne contiennent que nos clés
  (préfixe `webapp.`) ;
- au build, `merge_po.py` **fusionne** ces entrées dans
  `server/translations/<lang>/LC_MESSAGES/messages.po` — les catalogues amont
  restent donc à jour lors d'un changement de `AMC_WEBAPP_REV` ;
- `make` compile ensuite les `.mo`.

Côté templates : `{{ _('webapp.…') }}`, comme partout.
Côté JavaScript : `index.html` expose `window.AMC_I18N` (mêmes clés) et
`amc.js` les lit via `t('webapp.…')`.

> **Piège** : le `_()` de Jinja applique une mise en forme `%`. Une chaîne
> contenant un `%` littéral doit l'écrire `%%` dans le `.po`
> (ex. `Correspondance %%s %%`) ; Jinja la restitue en `%s` / `%` pour le JS.

Pour ajouter une chaîne : la déclarer dans les **deux** `extra-*.po`, l'utiliser
dans le template (`_()`) ou l'ajouter à `window.AMC_I18N` et l'appeler via `t()`
en JS, puis reconstruire.

## Ordre de construction

1. clone de `amc-webapp` → `/amc-web/`
2. copie de `overrides/` par-dessus
3. fusion des traductions de l'overlay (`webapp/i18n/` → catalogues amont)
4. `make` (traductions, ACE, icônes)
5. `flask digest compile`

> **Ne surchargez pas** les fichiers générés par `make` :
> `server/static/icons.css`, `server/ace/mode-amc_txt.js` et les
> `messages.mo` seraient écrasés par la construction.
> En revanche, surcharger un *template* suffit : `make icons` régénère
> `icons.css` à partir des templates.

## Reconstruire

Toute modification sous `overrides/` nécessite de reconstruire l'image :

```bash
docker compose --profile webapp up -d --build amc-web
# ou, via le lanceur : ./launch-web.sh
```

> Les noms d'assets sont **hachés** par `flask digest compile` (`amc-<hash>.css`).
> Un redémarrage simple ne suffit donc pas : il faut bien **reconstruire** après
> chaque modification de `amc.css` ou `amc.js`.

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
