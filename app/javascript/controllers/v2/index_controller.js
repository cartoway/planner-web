// Copyright © Cartoway
// Destinations index - Stimulus controller
// Prepared for Hotwire migration (Rails 6+)
// Requires: npm install @hotwired/stimulus

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['search', 'results']

  connect() {
    // Placeholder for future key:value search behavior
    if (typeof console !== 'undefined' && console.debug) {
      console.debug('[destinations-index] Controller connected')
    }
  }

  // Search with debounce - to be wired when search field is implemented
  search(event) {
    event.preventDefault()
    const query = this.hasSearchTarget ? this.searchTarget.value.trim() : ''
    if (query) {
      this.element.dispatchEvent(new CustomEvent('destinations:search', { detail: { query }, bubbles: true }))
    }
  }
}
