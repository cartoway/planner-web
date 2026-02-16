# Plan de route : Index Destinations V2

> **Migration effectuée** : l'index destinations utilise désormais le layout v2, les vues `app/views/v2/`, pagination serveur. L'ancienne page a été supprimée.

## 1. Inventaire des fonctionnalités de la page actuelle

### 1.1 Fonctionnalités principales

| Fonctionnalité | Description | Localisation |
|----------------|-------------|--------------|
| **Liste complète des destinations** | Toutes les destinations chargées en une fois via GET `/destinations.json` | Controller index → JSON → `displayDestinations()` |
| **Pagination côté client** | Pagination simulée par jQuery Tablesorter (100/200/500/1000/all) | `destinations.js` + select `.pagesize` |
| **Tri colonnes** | Tri par ref, nom, adresse, geocoding, commentaire, téléphone, tags | jQuery Tablesorter |
| **Filtrage colonnes** | Filtre texte par colonne (exact match, regex) | jQuery Tablesorter filters |
| **Sélection multiple** | Checkbox header + lignes, bouton "Supprimer la sélection" | `index_toggle_selection`, `#multiple-delete` |
| **Ajout destination** | Bouton "Nouveau" → création via API + prepend dans la table | `#add` → POST `/api/0.1/destinations.json` |
| **Compteurs** | Nombre de destinations et visites (si éditable) | `#count`, `#count-visits` |
| **Sélecteur de colonnes** | Dropdown pour afficher/masquer des colonnes | `#columnSelector` |

### 1.2 Colonnes affichées

- **Checkbox** (sélection)
- **Ref** (si `enable_references`)
- **Nom**
- **Adresse**
- **Geocoding** (précision %, avec aide au clic)
- **Commentaire**
- **Téléphone** (avec click2call si configuré)
- **Tags**
- **Visites** (si `is_editable`) : ref, tags, durée, créneaux horaires
- **Actions** (éditer, supprimer)

### 1.3 Fonctionnalités d’édition inline (mode éditable)

- Édition directe dans la table (champs texte, selects)
- Geocoding : modification adresse → appel API geocode
- Clic sur carte pour positionner (mode "pointing")
- Glisser-déposer des marqueurs sur la carte
- Select2 pour les tags
- TimeEntry pour durées et créneaux
- Mise à jour via PATCH `/api/0.1/destinations/:id.json`

### 1.4 Carte Leaflet

- Marqueurs clusterisés (MarkerClusterGroup)
- Interaction clic marqueur ↔ surlignage ligne
- Ajustement des bounds au chargement
- Support multi-couches (layers)

### 1.5 Modales et dialogues

- **Modal geocoding danger** : tri par précision geocoding, aide
- **Dialog geocoding en cours** : attente job geocoding
- **ProgressDialog** pour imports / traitements longs

### 1.6 Contraintes et alertes

- Alerte `too_many_destinations?` si dépassement de la limite
- Masquage du bouton "Nouveau" si `reached_max_destinations`

### 1.7 Données injectées côté serveur

```ruby
controller.js(
  is_editable: @customer.is_editable?,
  reached_max_destinations: @destinations.size > @customer.default_max_destinations,
  map_layers: Hash[...],
  map_lat: @customer.default_position[:lat],
  map_lng: @customer.default_position[:lng],
  default_city: @customer.stores[0].city,
  default_country: @customer.default_country,
  duration_default: @customer.visit_duration_time_with_seconds,
  url_click2call: current_user.link_phone_number,
  enable_references: @customer.enable_references
)
```

---

## 2. Layout V2 : Importmaps + Hotwire (Rails 6)

### 2.1 Objectifs

- Préparer la migration vers Rails 7
- Utiliser **importmap-rails** à la place de Webpacker pour la nouvelle partie
- Utiliser **Hotwire** (Turbo + Stimulus)
- Coexistence avec l’existant (pages legacy)

### 2.2 Gems à ajouter

```ruby
# Gemfile
gem 'importmap-rails'
gem 'stimulus-rails'
gem 'turbo-rails'  # Turbo 8 compatible Rails 6
```

### 2.3 Structure fichiers

```
app/
  javascript/
    packs/
      v2/
        application.js
    controllers/
      v2/
        index_controller.js
    ...
  views/
    v2/                       # V2 (vues + layouts, sans suffixe v2 dans les noms)
      layouts/
        application.html.haml
        _head.html.haml
      destinations/
        index.html.haml
```

### 2.4 config/importmap.rb

```ruby
pin "application", preload: true
pin "@hotwired/stimulus", to: "stimulus.min.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus-loading.js", preload: true
pin "@hotwired/turbo-rails", to: "turbo.min.js", preload: true
pin_all_from "app/javascript/controllers", under: "controllers"
```

### 2.5 Layout V2

Le layout `application_v2` devra :

- Utiliser `javascript_importmap_tags` à la place de `javascript_pack_tag`
- Inclure Turbo (`turbo_include_tags`) – **en place** : navigation v2 ne recharge que `.main`
- Garder les styles existants (vendor_stylesheet, application)
- Exposer les contrôleurs Stimulus sur le body ou des conteneurs dédiés

**Turbo Frame « main » (implémenté)** : le contenu de `.main` est enveloppé dans `turbo_frame_tag "main"`. Les liens dans le menu vers des pages v2 ont `data-turbo-frame="main"`. Seul le contenu du frame est mis à jour lors de la navigation v2 → v2.

### 2.6 Stratégie de coexistence

- Routes dédiées pour la V2 : `/destinations/v2` ou `?layout=v2`
- Ou : `layout "application_v2"` dans un controller spécifique `DestinationsV2Controller`

---

## 3. Liste paginée côté serveur (destination/visite)

### 3.1 Modèle de données

- **Destination** : id, ref, name, street, postalcode, city, country, lat, lng, phone_number, comment, tags, geocoding_accuracy, etc.
- **Visit** : id, destination_id, ref, duration, time_windows, tags, quantities, etc.

Relation : une destination a plusieurs visites. L’unité d’affichage côté liste = **couple destination/visite(s)**.

### 3.2 Options de pagination

| Option | Avantage | Inconvénient |
|--------|----------|--------------|
| Pagination par destination | Simple, alignée avec le modèle | Visites multiples = plusieurs lignes par destination |
| Pagination par couple (destination + visites) | Une ligne par destination avec ses visites | Nécessite un scope/comptage adapté |

**Recommandation** : pagination par **destination**, avec `includes(:visits)` pour éviter les N+1.

### 3.3 Implémentation avec Pagy

```ruby
# destinations_controller.rb (ou DestinationsV2Controller)
def index
  @customer = current_user.customer
  scope = @customer.destinations
    .reorder(Arel.sql("CASE WHEN lat IS NULL THEN 0 ELSE 1 END, geocoding_accuracy ASC NULLS LAST"))
    .includes_visits

  # Pagination côté serveur
  @pagy, @destinations = pagy(scope, items: params[:per_page] || 25)
end
```

### 3.4 Endpoint pour Turbo Frames

- `GET /destinations?v2=1` : HTML avec Turbo Frame
- Ou `GET /destinations/v2` : page dédiée V2

Réponse :

- Page : frame avec liste + pagination
- Lien “Suivant” / numéros : Turbo Frame refresh

---

## 4. Recherche clé:valeur sur champs prédéterminés

### 4.1 Format attendu

```
field:value
```

Exemples :

- `name:Dupont`
- `ref:D001`
- `city:Lyon`
- `tags:urgent`

### 4.2 Champs autorisés (liste prédéterminée)

| Clé | Champ | Scope AR / Requête |
|-----|-------|--------------------|
| `ref` | Destination.ref | `where("destinations.ref ILIKE ?", "%value%")` |
| `name` | Destination.name | `where("destinations.name ILIKE ?", "%value%")` |
| `address` | street, postalcode, city, country | `where("... OR ... OR ...")` |
| `city` | Destination.city | `where("destinations.city ILIKE ?", "%value%")` |
| `postalcode` | Destination.postalcode | `where("destinations.postalcode ILIKE ?", "%value%")` |
| `country` | Destination.country | `where("destinations.country ILIKE ?", "%value%")` |
| `phone` | Destination.phone_number | `where("destinations.phone_number ILIKE ?", "%value%")` |
| `comment` | Destination.comment | `where("destinations.comment ILIKE ?", "%value%")` |
| `tags` | Tag.label (via tag_destinations) | `joins(:tags).where("tags.label ILIKE ?", "%value%")` |
| `visit_ref` | Visit.ref | `joins(:visits).where("visits.ref ILIKE ?", "%value%")` |
| `visit_tags` | Visit tags | `joins(visits: :tags).where("tags.label ILIKE ?", "%value%")` |

### 4.3 Parsing de la recherche

```ruby
# app/services/destination_search_parser.rb
class DestinationSearchParser
  ALLOWED_KEYS = %w[ref name address city postalcode country phone comment tags visit_ref visit_tags].freeze

  def initialize(query)
    @query = query.to_s.strip
  end

  def parse
    return [] if @query.blank?

    conditions = []
    if @query.include?(':')
      @query.split(/\s+/).each do |part|
        key, value = part.split(':', 2)
        next if value.blank?
        conditions << { key: key.downcase, value: value.strip } if ALLOWED_KEYS.include?(key.downcase)
      end
    else
      # Fallback: recherche globale sur name + address + city
      conditions << { key: 'name', value: @query }
      conditions << { key: 'city', value: @query }
    end
    conditions
  end
end
```

### 4.4 Application au scope

```ruby
def apply_search(scope, conditions)
  conditions.each do |c|
    scope = case c[:key]
    when 'ref' then scope.where("destinations.ref ILIKE ?", "%#{sanitize(c[:value])}%")
    when 'name' then scope.where("destinations.name ILIKE ?", "%#{sanitize(c[:value])}%")
    # ... etc
    end
  end
  scope
end
```

### 4.5 Interface utilisateur

- Champ texte avec placeholder : `Ex: name:Dupont city:Lyon`
- Aide inline : liste des clés autorisées
- Déclenchement : bouton ou `input` (debounce pour éviter trop de requêtes)

---

## 5. Plan de route détaillé

### Phase 1 : Infrastructure (1–2 jours)

- [x] Ajouter la gem `turbo-rails` (layout v2 uniquement)
- [ ] Ajouter les gems : `importmap-rails`, `stimulus-rails`
- [ ] `rails importmap:install`
- [ ] `rails stimulus:install`
- [ ] Créer `app/views/v2/layouts/application.html.haml` avec `javascript_importmap_tags` et Turbo
- [ ] Créer une route de test pour vérifier le layout V2

### Phase 2 : Pagination serveur (1 jour)

- [ ] Modifier `DestinationsController#index` pour accepter `format: :html` avec pagination
- [ ] Créer un controller `DestinationsV2Controller` (ou namespace) utilisant `layout "application v2"`
- [ ] Appliquer Pagy dans l’action `index`
- [ ] Créer les partials `_destination_row.html.erb` et `_destinations_table.html.erb`

### Phase 3 : Endpoint JSON paginé (0,5 jour)

- [ ] Endpoint `GET /destinations.json` avec params `page`, `per_page`
- [ ] Adapter le jbuilder pour retourner `{ destinations: [...], meta: { page, total_pages, total_count } }`

### Phase 4 : Recherche clé:valeur (1–1,5 jour)

- [ ] Créer `DestinationSearchParser` (service)
- [ ] Créer `DestinationSearchScope` ou méthodes dans le modèle
- [ ] Intégrer la recherche dans `DestinationsV2Controller#index`
- [ ] Tests unitaires pour le parser et les scopes

### Phase 5 : Vue V2 avec Turbo Frames (2–3 jours)

- [ ] Vue `v2/destinations/index.html.erb` avec Turbo Frames
- [ ] Frame pour la liste paginée
- [ ] Frame pour la carte (optionnel en V2, ou simplifié)
- [ ] Lazy load des pages suivantes ou navigation classique
- [ ] Champ recherche avec stimulus controller (debounce)

### Phase 6 : Migration des fonctionnalités (3–5 jours)

- [ ] Sélection multiple (checkboxes) avec Stimulus
- [ ] Suppression multiple
- [ ] Carte Maplibre (Stimulus controller)
- [ ] Lien clic ligne ↔ marqueur (comportement existant)
- [ ] Édition inline : décider entre conservation ou formulaire modal

### Phase 7 : Tests et polish (1–2 jours)

- [ ] Tests d’intégration pour la page V2
- [ ] Tests pour la recherche clé:valeur
- [ ] Vérification des performances (N+1, temps de réponse)
- [ ] Documentation et nettoyage

---

## 6. Estimation globale

| Phase | Durée | Priorité |
|-------|-------|----------|
| 1. Infrastructure | 1–2 j | P0 |
| 2. Pagination serveur | 1 j | P0 |
| 3. Endpoint JSON paginé | 0,5 j | P1 |
| 4. Recherche clé:valeur | 1–1,5 j | P0 |
| 5. Vue V2 Turbo Frames | 2–3 j | P0 |
| 6. Migration fonctionnalités | 3–5 j | P1 |
| 7. Tests et polish | 1–2 j | P0 |

**Total estimé** : 10–15 jours ouvrés.

---

## 7. Risques et points d’attention

1. **Cohabitation layout** : conflits entre Turbolinks 5 et Turbo 8 sur les autres pages.
2. **Paloma** : le système actuel repose sur Paloma pour router le JS. La V2 doit fonctionner sans Paloma ou avec une adaptation.
3. **API existante** : `/api/0.1/destinations` est utilisée pour l’édition. Vérifier que la pagination HTML n’impacte pas les consommateurs de l’API.
4. **Carte** : Maplibre + MarkerCluster nécessite un portage propre en Stimulus pour éviter les fuites mémoire (event listeners, etc.).

---

## 8. Références

- [Hotwire - Installation Importmaps](https://hotwire.io/frameworks/rails/setup/installation-importmaps)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook)
- [Pagy Documentation](https://ddnexus.github.io/pagy/)
- [Turbo Frames](https://turbo.hotwired.dev/handbook/frames)
