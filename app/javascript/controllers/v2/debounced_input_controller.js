// Copyright © Cartoway
// Shared debounce for v2 filter fields. Dispatches `debounced-input:flush` after delay.
import { Controller } from '@hotwired/stimulus'

export const DEFAULT_DELAY_MS = 500

export default class extends Controller {
  static values = {
    delay: { type: Number, default: DEFAULT_DELAY_MS }
  }

  connect () {
    this._timer = null
  }

  disconnect () {
    this._clearTimer()
  }

  queue () {
    this._clearTimer()
    this._timer = window.setTimeout(() => this.flush(), this.delayValue)
  }

  flush (event) {
    this._clearTimer()
    if (event?.type === 'keydown') event.preventDefault()
    this.dispatch('flush', { detail: { value: this.element.value } })
  }

  _clearTimer () {
    window.clearTimeout(this._timer)
    this._timer = null
  }
}
