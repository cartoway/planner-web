// Copyright © Cartoway
// Shared debounce for v2 filter fields. Dispatches `debounced-input:flush` after delay.
// Set preserveFocus when the flush triggers a Turbo replace of the input.
import { Controller } from '@hotwired/stimulus'
import { captureFilterFocus, restoreFilterFocus } from 'lib/filter_input_focus'

export const DEFAULT_DELAY_MS = 500

export default class extends Controller {
  static values = {
    delay: { type: Number, default: DEFAULT_DELAY_MS },
    preserveFocus: { type: Boolean, default: false }
  }

  connect () {
    this._timer = null
    if (this.preserveFocusValue) restoreFilterFocus()
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
    if (this.preserveFocusValue) captureFilterFocus(this.element)
    this.dispatch('flush', { detail: { value: this.element.value } })
  }

  _clearTimer () {
    window.clearTimeout(this._timer)
    this._timer = null
  }
}
