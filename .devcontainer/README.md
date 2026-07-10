# Devcontainer — régression visuelle Lookbook

Guide pour valider les changements UI dans le stack Docker local. Référence technique complète : [`visual-regression/README.md`](../visual-regression/README.md).

## Prérequis

1. Copier la config d’environnement :
   ```bash
   cp .devcontainer/.env.template .env
   ```
2. (Optionnel) Activer les alias shell :
   ```bash
   source .devcontainer/aliases.sh
   ```
3. Démarrer la stack :
   ```bash
   planner-dev-up
   # ou : .devcontainer/compose.sh up --build -d
   ```

## Deux serveurs, deux rôles

| Port | Service | Rôle |
|------|---------|------|
| **8080** | Puma (`RAILS_ENV=production`) | App + Lookbook au quotidien, assets précompilés |
| **3001** | Rails test (`RAILS_ENV=test`) | Cible Playwright — **même env que la CI** |

Le port 8080 sert à parcourir Lookbook à l’œil. La **validation VRT** passe obligatoirement par Playwright sur **3001** (Webpacker test, pipeline différent de 8080).

## Activer la VRT

Dans `.env` à la racine du projet :

```bash
LOOKBOOK_VRT=1
```

Puis redémarrer la stack (`planner-dev-up`).

Quand `LOOKBOOK_VRT=1` :

- `web` démarre aussi Rails test sur **3001** (voir `start-web.sh`)
- au `compose up`, les services **`lookbook-vrt`** (Playwright) puis **`lookbook-vrt-export`** (export du rapport) s’exécutent une fois

Avec `LOOKBOOK_VRT=0` (défaut), ces services sortent immédiatement sans lancer Playwright.

## Voir le rapport

Après un run (auto ou manuel) :

**http://localhost:8080/lookbook/preview/design_system/visual_regression/report**

Le rapport lit `public/lookbook-visual-regression/manifest.json` et les PNG copiés depuis Playwright. Ces fichiers sont montés depuis l’hôte :

- `visual-regression/` → snapshots (`*-linux.png`) + `test-results/`
- `public/lookbook-visual-regression/` → rapport Lookbook

## Workflow de validation

### 1. Lancer la comparaison

**Automatique** (si `LOOKBOOK_VRT=1` au démarrage) :

```bash
planner-dev-up
docker compose -f .devcontainer/docker-compose.yml ps -a   # attendre lookbook-vrt-export "exited"
```

**Manuel** (stack déjà up) :

```bash
planner-dev-vrt test
# ou : .devcontainer/visual-regression.sh test
```

`test` prépare Rails sur 3001, lance Playwright dans l’image Ubuntu (Chromium ne tourne pas dans l’image Alpine `web`), puis exporte le rapport Lookbook.

### 2. Examiner les diffs

Dans le rapport Lookbook : colonnes **Expected** / **Actual** / **Diff** pour chaque preview en échec.

Alternative Playwright (rapport HTML détaillé) :

```bash
planner-dev-vrt report   # http://127.0.0.1:9323
```

### 3. Décider

| Situation | Action |
|-----------|--------|
| Régression involontaire | Corriger le CSS/composant, relancer `planner-dev-vrt test` |
| Changement visuel voulu | Accepter la nouvelle baseline (étape 4) |

### 4. Accepter une baseline (dev uniquement)

Sur le rapport Lookbook, boutons **Accepter la baseline** / **Accepter tous les changements** (si `LOOKBOOK_VRT=1`).

Confirmation en **deux clics** avec délai (même UX que la suppression sur la liste destinations V2).

Cela :

1. copie `actual.png` vers `visual-regression/tests/lookbook.vrt.spec.ts-snapshots/*-linux.png` sur l’hôte
2. nettoie les artefacts Playwright du preview
3. ré-exporte le manifeste (la ligne passe en **passed**)

**Commiter** les PNG modifiés dans le même PR que le changement UI.

### 5. Mise à jour en masse (ligne de commande)

Équivalent à « update snapshots » Playwright :

```bash
planner-dev-vrt update                              # tous les previews
planner-dev-vrt update -g 'lookbook: buttons-variants'   # un seul
```

Puis vérifier le diff git :

```bash
git diff visual-regression/tests/lookbook.vrt.spec.ts-snapshots/
```

## Quand mettre à jour les snapshots ?

**Non** à chaque changement. **Oui** seulement si tu modifies volontairement le rendu d’un preview couvert (SCSS, HAML, fixtures Lookbook, nouveau preview dans `LOOKBOOK_PREVIEWS`, etc.).

La CI exécute le job `lookbook_visual` après `test` et `lint` (voir `.github/workflows/rubyonrails.yml`).

## Commandes utiles

| Commande | Description |
|----------|-------------|
| `planner-dev-up` | Build + démarrage stack |
| `planner-dev-vrt test` | Comparaison + export rapport Lookbook |
| `planner-dev-vrt export` | Ré-exporte le manifeste sans relancer Playwright |
| `planner-dev-vrt report` | Rapport HTML Playwright |
| `planner-dev-vrt update` | Régénère les baselines `*-linux.png` |
| `planner-dev-vrt prepare` | Rails test :3001 seulement |

## Dépannage

**« No report yet »** — le manifeste n’existe pas. Lancer `planner-dev-vrt test` ou vérifier que `lookbook-vrt-export` a terminé sans erreur (`docker logs devcontainer-lookbook-vrt-export-1`).

**Bouton Accepter inactif** — vérifier `LOOKBOOK_VRT=1` dans `.env` et redémarrer `web`.

**Code JS / template rapport pas à jour** — l’image `web` embarque le code au build ; certains chemins VRT sont montés en volume. En cas de doute : `planner-dev-up --build`, ou utiliser `planner-dev-vrt` (montage workspace complet pour Playwright).

**Snapshots acceptés sur l’hôte mais rapport inchangé** — relancer `planner-dev-vrt export` ; l’accept déclenche normalement un ré-export automatique.

## Architecture (services Docker)

```
web:8080          → Puma production (Lookbook navigation)
web:3001          → Rails test (cible Playwright, si LOOKBOOK_VRT=1)
lookbook-vrt      → Playwright (image Ubuntu), one-shot au up
lookbook-vrt-export → ruby script/export_lookbook_visual_regression_report.rb
```

Playwright **ne s’exécute pas** dans `docker exec web` (Alpine / Chromium absent). Toujours passer par `planner-dev-vrt` ou le service `lookbook-vrt`.
