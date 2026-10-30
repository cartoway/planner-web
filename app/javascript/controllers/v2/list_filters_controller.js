// Copyright © Cartoway
// Auto-submit GET list filters (debounced search via v2--debounced-input + date/chip change).
// Prefer targeting a results turbo-frame so the search input is never replaced.
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['form', 'search', 'status']

  submitNow () {
    if (this.hasFormTarget) this.formTarget.requestSubmit()
  }

  pickChip (event) {
    const clicked = event.currentTarget
    if (this.hasStatusTarget) this.statusTarget.value = clicked.dataset.value || ''
    this.element.querySelectorAll('.v2-list-filters-chips .btn').forEach((btn) => {
      const on = btn === clicked
      btn.classList.toggle('btn-primary', on)
      btn.classList.toggle('btn-outline-secondary', !on)
    })
    this.submitNow()
  }
}
