// Copyright © Cartoway
// Application pack - prepared for Importmaps + Hotwire (Rails 6+)
// Placeholder for Stimulus controllers. Add @hotwired/stimulus when upgrading:
//   import { Application } from '@hotwired/stimulus'
//   import IndexController from '../../controllers/v2/index_controller'
//   const application = Application.start()
//   application.register('destinations-index', IndexController)

'use strict'

// Bootstrap for v2 layout - no jQuery dependency, works with Turbolinks
const initV2 = function () {
  if (document.body.dataset.controller && document.body.dataset.controller.includes('v2')) {
    window.dispatchEvent(new CustomEvent('application-v2:loaded'))
  }
}
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initV2)
} else {
  initV2()
}
document.addEventListener('turbolinks:load', initV2)
