// Copyright © Cartoway
// V2 destination sidebar: delete a persisted visit immediately (PATCH nested _destroy), then reload turbo-frame#form_sidebar.
import { Controller } from '@hotwired/stimulus'
import { visit } from '@hotwired/turbo'

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

  async confirmAndDestroy (event) {
    event.preventDefault()
    const msg = this.confirmMessageValue || ''
    if (!window.confirm(msg)) return

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

      const okish = res.ok || res.status === 302 || res.status === 303 || res.status === 204
      if (res.status === 422) {
        window.alert(this.errorValidationMessageValue || this.errorRequestMessageValue)
        visit(this.frameReloadUrlValue, { frame: 'form_sidebar' })
        return
      }
      if (!okish) {
        window.alert(this.errorRequestMessageValue)
        return
      }
      visit(this.frameReloadUrlValue, { frame: 'form_sidebar' })
    } catch (e) {
      window.alert(this.errorNetworkMessageValue || this.errorRequestMessageValue)
    } finally {
      el.disabled = false
    }
  }
}
