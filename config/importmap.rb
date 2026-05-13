# frozen_string_literal: true

# Copyright © Cartoway
# Importmap + Hotwire (Turbo + Stimulus) for the v2 layout — no Webpack.
# - Entry must NOT be named application.js: Sprockets already serves app/assets/javascripts/application.js (legacy).
# - @hotwired/stimulus-loading is not on npm; vendor/javascript/stimulus_loading.js is copied from stimulus-rails.
# - unpkg serves ESM with text/javascript + CORS (jsDelivr +esm can be text/plain / 404 and breaks Firefox modules).

pin "application", to: "hotwire_entry.js", preload: true
pin "@hotwired/turbo", to: "https://unpkg.com/@hotwired/turbo@8.0.13/dist/turbo.es2017-esm.js", preload: true
pin "@hotwired/stimulus", to: "https://unpkg.com/@hotwired/stimulus@3.2.2/dist/stimulus.js", preload: true
pin "@hotwired/stimulus-loading", to: "stimulus_loading.js", preload: true
pin_all_from "app/javascript/maplibre", under: "maplibre"
pin_all_from "app/javascript/controllers", under: "controllers"
