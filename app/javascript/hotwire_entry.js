// Copyright © Cartoway
// V2 layout entry — Hotwire (Turbo + Stimulus) via importmap.
// Named hotwire_entry.js so Sprockets does not resolve pin "application" to app/assets/javascripts/application.js (jQuery / I18n bundle).
import "@hotwired/turbo"
import "controllers"
import { installTurboNetworkErrorHandling } from "turbo/network_error"
import { installV2BodyPageSync } from "lib/v2_body_page"

installTurboNetworkErrorHandling()
installV2BodyPageSync()

