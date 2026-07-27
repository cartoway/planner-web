// Copyright © Cartoway
// Remove an unsaved visit fieldset from the nested form (no server round-trip).
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  connect () {
    this._onConfirmed = (event) => {
      if (event.detail?.element !== this.element) return
      this.remove(event)
    }
    this.element.addEventListener('confirm-click:confirmed', this._onConfirmed)
  }

  disconnect () {
    this.element.removeEventListener('confirm-click:confirmed', this._onConfirmed)
  }

  remove (event) {
    event.preventDefault()

    const fieldset = this.element.closest('fieldset.visit-fieldset')
    if (!fieldset) return

    const visitsList = document.getElementById('visits')
    const destroyInput = fieldset.querySelector('input[name*="[_destroy]"]')
    if (destroyInput) destroyInput.checked = true

    fieldset.remove()
    if (visitsList) {
      const ctrl = this.application.getControllerForElementAndIdentifier(visitsList, 'v2--visit-list')
      ctrl?.syncHeader()
    }
    this._markFormDirty()
  }

  _markFormDirty () {
    const form = document.getElementById('destination-form-sidebar')
    form?.dispatchEvent(new Event('input', { bubbles: true }))
  }
}
