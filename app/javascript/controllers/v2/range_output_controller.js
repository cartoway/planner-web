// Copyright © Cartoway
// Keeps a text display in sync with an <input type="range"> (e.g. visit priority).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["display"]

  connect () {
    this.sync()
  }

  sync (event) {
    const input = event?.currentTarget || this.element.querySelector('input[type="range"]')
    if (!this.hasDisplayTarget || !input) return
    this.displayTarget.textContent = input.value
  }
}
