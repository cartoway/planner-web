// Copyright © Cartoway
// Lookbook preview shell — Stimulus + Tom Select only (no Turbo; avoids hijacking Lookbook navigation).
import { Application } from "@hotwired/stimulus"
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading"

const application = Application.start()
application.debug = false
window.Stimulus = application

eagerLoadControllersFrom("controllers", application)
