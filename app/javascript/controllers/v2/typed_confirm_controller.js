// Copyright © Cartoway
// Modal that requires typing an expected string before enabling confirm.
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'submit', 'form']
  static values = { expected: String }

  connect () {
    this.sync()
  }

  sync () {
    if (!this.hasSubmitTarget) return
    const typed = this.hasInputTarget ? this.inputTarget.value.trim() : ''
    this.submitTarget.disabled = typed !== this.expectedValue.trim()
  }

  reset () {
    if (this.hasInputTarget) this.inputTarget.value = ''
    this.sync()
  }

  // Dismiss modal + leftover backdrop before Turbo/Drive navigates away.
  prepareSubmit () {
    const modal = window.bootstrap?.Modal?.getInstance(this.element)
    if (modal) modal.hide()
    document.body.classList.remove('modal-open')
    document.body.style.removeProperty('overflow')
    document.body.style.removeProperty('padding-right')
    document.querySelectorAll('.modal-backdrop').forEach((el) => el.remove())
  }
}
