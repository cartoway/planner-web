// Copyright © Cartoway
// V2 destination sidebar: delete a persisted visit immediately (PATCH nested _destroy), remove fieldset without full reload.
import { Controller } from '@hotwired/stimulus'

function dispatchDestinationVisitsChanged (destinationId) {
  if (!destinationId) return
  document.dispatchEvent(new CustomEvent('v2:destination-visits-changed', {
    bubbles: true,
    detail: { destinationId: String(destinationId) }
  }))
}

function destinationIdFromSidebarForm () {
  return document.getElementById('destination-form-sidebar')?.getAttribute('data-destination_id') || null
}

export default class extends Controller {
  static values = {
    visitId: Number,
    updateUrl: String,
    frameReloadUrl: String,
    confirmMessage: String,
    errorValidationMessage: String,
    errorRequestMessage: String,
    errorNetworkMessage: String
  }

  connect () {
    this._onConfirmed = (event) => {
      if (event.detail?.element !== this.element) return
      this.destroy(event)
    }
    this.element.addEventListener('confirm-click:confirmed', this._onConfirmed)
  }

  disconnect () {
    this.element.removeEventListener('confirm-click:confirmed', this._onConfirmed)
  }

  async destroy (event) {
    event.preventDefault()
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content')
    const body = new URLSearchParams()
    body.set('destination[visits_attributes][0][id]', String(this.visitIdValue))
    body.set('destination[visits_attributes][0][_destroy]', '1')

    const el = this.element
    el.disabled = true
    try {
      const res = await fetch(this.updateUrlValue, {
        method: 'PATCH',
        headers: {
          Accept: 'text/html, application/xhtml+xml',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'X-CSRF-Token': token || '',
          'Turbo-Frame': 'form_sidebar'
        },
        body,
        redirect: 'manual'
      })

      const redirectedManually = res.type === 'opaqueredirect' || res.status === 0
      const okish = res.ok || redirectedManually || res.status === 302 || res.status === 303 || res.status === 204
      if (res.status === 422) {
        window.alert(this.errorValidationMessageValue || this.errorRequestMessageValue)
        return
      }
      if (!okish) {
        window.alert(this.errorRequestMessageValue)
        return
      }
      this._removeFieldset()
      dispatchDestinationVisitsChanged(destinationIdFromSidebarForm())
    } catch (e) {
      window.alert(this.errorNetworkMessageValue || this.errorRequestMessageValue)
    } finally {
      el.disabled = false
    }
  }

  _removeFieldset () {
    const fieldset = this.element.closest('fieldset.visit-fieldset') ||
      document.getElementById(`visit-fieldset-${this.visitIdValue}`)
    fieldset?.remove()
    const list = document.getElementById('visits')
    if (list) {
      const ctrl = this.application.getControllerForElementAndIdentifier(list, 'v2--visit-list')
      ctrl?.syncHeader()
    }
  }
}
