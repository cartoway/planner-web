// Copyright © Cartoway
// Auto-submit column visibility form and sync hidden[] from unchecked boxes.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit() {
    this.element.querySelectorAll('input[name="hidden[]"]').forEach((input) => input.remove())
    this.element.querySelectorAll('input[type="checkbox"][name="active[]"]').forEach((checkbox) => {
      if (checkbox.checked) return
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = "hidden[]"
      hidden.value = checkbox.value
      this.element.appendChild(hidden)
    })
    this.element.requestSubmit()
  }
}
