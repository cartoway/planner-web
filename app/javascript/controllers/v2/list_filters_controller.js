// Copyright © Cartoway
// Auto-submit GET list filters (search debounce + date/chip change).
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'search']
  static values = { debounce: { type: Number, default: 300 } }

  connect () {
    this._timer = null
  }

  disconnect () {
    window.clearTimeout(this._timer)
  }

  submitSoon () {
    window.clearTimeout(this._timer)
    this._timer = window.setTimeout(() => this.submitNow(), this.debounceValue)
  }

  submitNow () {
    window.clearTimeout(this._timer)
    if (this.hasFormTarget) this.formTarget.requestSubmit()
  }
}
