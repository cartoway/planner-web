// Copyright © Cartoway
// Toast host: showToast API + Stimulus actions with message / className / sticky params.
import { Controller } from '@hotwired/stimulus'
import { clearToasts, showToast } from 'lib/toast'

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 6000 }
  }

  // data-action="click->v2--toast#notify"
  // data-v2--toast-message-param="…" data-v2--toast-class-name-param="alert-success"
  // data-v2--toast-sticky-param="true"
  notify (event) {
    event?.preventDefault?.()
    const params = event?.params || {}
    showToast({
      message: params.message,
      className: params.className || 'alert-info',
      sticky: !!params.sticky,
      delay: this.delayValue
    }, document)
  }

  clear () {
    clearToasts(document)
  }
}
