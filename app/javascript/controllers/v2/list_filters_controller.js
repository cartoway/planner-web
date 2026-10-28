// Copyright © Cartoway
// Auto-submit GET list filters (debounced search via v2--debounced-input + date/chip change).
import { Controller } from '@hotwired/stimulus'
import { captureFilterFocus } from 'lib/filter_input_focus'

export default class extends Controller {
  static targets = ['form', 'search']

  submitNow () {
    if (this.hasSearchTarget) captureFilterFocus(this.searchTarget)
    if (this.hasFormTarget) this.formTarget.requestSubmit()
  }
}
