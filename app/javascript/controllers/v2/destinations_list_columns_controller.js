// Copyright © Cartoway
// Submits destinations list column preferences after checklist mutations.
// Form targets destinations_list_body so the dropdown/toolbar stay mounted.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  connect() {
    this._onChange = this.submit.bind(this)
    this.element.addEventListener("searchable-checklist-dropdown:change", this._onChange)
  }

  disconnect() {
    this.element.removeEventListener("searchable-checklist-dropdown:change", this._onChange)
  }

  submit() {
    if (!this.hasFormTarget) return

    this.formTarget.querySelectorAll('input[name="hidden[]"]').forEach((input) => input.remove())
    this.formTarget.querySelectorAll('input[type="checkbox"]').forEach((checkbox) => {
      if (checkbox.checked) return
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = "hidden[]"
      hidden.value = checkbox.value
      this.formTarget.appendChild(hidden)
    })
    this.formTarget.requestSubmit()
  }
}
