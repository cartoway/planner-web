// Copyright © Cartoway
// Accept Playwright snapshot baselines from the Lookbook visual regression report.
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static values = {
    acceptUrl: String,
    acceptAllUrl: String
  }

  connect () {
    this._csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute('content') || ''
    this._onConfirmed = (event) => this.confirmed(event)
    this.element.addEventListener('confirm-click:confirmed', this._onConfirmed)
  }

  disconnect () {
    this.element.removeEventListener('confirm-click:confirmed', this._onConfirmed)
  }

  confirmed (event) {
    const button = event.detail?.element
    if (!button) return

    if (button.dataset.acceptAll === 'true') {
      this._acceptAll()
      return
    }

    const name = button.dataset.previewName
    if (!name) return

    this._acceptOne(name)
  }

  _acceptOne (name) {
    this._post(this.acceptUrlValue, { name })
      .then(() => { window.location.reload() })
      .catch((error) => { window.alert(error.message) })
  }

  _acceptAll () {
    this._post(this.acceptAllUrlValue, {})
      .then(() => { window.location.reload() })
      .catch((error) => { window.alert(error.message) })
  }

  async _post (url, body) {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'X-CSRF-Token': this._csrfToken
      },
      body: JSON.stringify(body)
    })

    const payload = await response.json().catch(() => ({}))
    if (!response.ok || !payload.ok) {
      throw new Error(payload.error || 'Request failed')
    }
    return payload
  }
}
