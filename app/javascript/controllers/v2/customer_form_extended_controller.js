// Copyright © Cartoway
import { Controller } from "@hotwired/stimulus"

// Shows the sections the admin form hides until "extended options" is checked.
// The v1 page did this in customers.js (jQuery), which the v2 layout does not load.
export default class extends Controller {
  toggle (event) {
    const hidden = !event.target.checked
    this.element.querySelectorAll(".customer-form-extended").forEach((section) => {
      section.classList.toggle("d-none", hidden)
    })
  }
}
