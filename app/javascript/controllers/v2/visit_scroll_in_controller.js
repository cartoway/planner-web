// Copyright © Cartoway
// Newly appended visit fieldset: delegate smooth reveal to v2--visit-list on #visits.
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect () {
    requestAnimationFrame(() => {
      const visitId = this._visitId()
      if (!visitId) return

      const list = this.element.closest('#visits')
      if (!list) return

      const ctrl = this.application.getControllerForElementAndIdentifier(list, 'v2--visit-list')
      ctrl?.revealVisit(visitId)
    })
  }

  _visitId () {
    const match = this.element.id?.match(/^visit-fieldset-(\d+)$/)
    return match ? Number(match[1]) : null
  }
}
