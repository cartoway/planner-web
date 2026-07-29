# frozen_string_literal: true

# Copyright © Cartoway
# Importmap + Hotwire (Turbo + Stimulus) for the v2 layout — no Webpack.
# - Entry must NOT be named application.js: Sprockets already serves app/assets/javascripts/application.js (legacy).
# - @hotwired/stimulus-loading is not on npm; vendor/javascript/stimulus_loading.js is copied from stimulus-rails.
# - unpkg serves ESM with text/javascript + CORS (jsDelivr +esm can be text/plain / 404 and breaks Firefox modules).

pin "application", to: "hotwire_entry.js", preload: true
pin "lookbook_entry", to: "lookbook_entry.js", preload: false
pin "@hotwired/turbo", to: "https://unpkg.com/@hotwired/turbo@8.0.13/dist/turbo.es2017-esm.js", preload: true
pin "@hotwired/stimulus", to: "https://unpkg.com/@hotwired/stimulus@3.2.2/dist/stimulus.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus_loading.js", preload: true
pin "turbo/frame_promoted_visit", to: "turbo/frame_promoted_visit.js", preload: true
pin_all_from "app/javascript/maplibre", under: "maplibre"
pin_all_from "app/javascript/controllers", under: "controllers"
# Tom Select ESM pulls @orchidjs/* bare specifiers; map them for the browser importmap (see tom-select dist/esm/tom-select.js).
pin "@orchidjs/sifter", to: "https://cdn.jsdelivr.net/npm/@orchidjs/sifter@1.1.0/+esm"
pin "@orchidjs/unicode-variants", to: "https://cdn.jsdelivr.net/npm/@orchidjs/unicode-variants@1.1.2/+esm"
# Tom Select (ESM complete build: plugins resolve relative to this URL on the CDN)
pin "tom-select", to: "https://cdn.jsdelivr.net/npm/tom-select@2.4.3/dist/esm/tom-select.complete.js", preload: true
