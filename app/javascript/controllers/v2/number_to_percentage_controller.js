// Copyright © Cartoway
// On submit, turn percent number inputs into 0–1 hidden fields (replaces jQuery .number-to-percentage).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    // Fallback param name when input has no data-param-path: prefix[inputName]
    prefix: { type: String, default: "" }
  }

  submit (event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    form.querySelectorAll('input[type="number"].number-to-percentage').forEach((input) => {
      const raw = input.value
      const value = raw === "" ? null : Number(raw) / 100
      const name = input.dataset.paramPath || (this.prefixValue ? `${this.prefixValue}[${input.name}]` : input.name)
      form.querySelectorAll("input[type=\"hidden\"][data-number-to-percentage-for]").forEach((el) => {
        if (el.dataset.numberToPercentageFor === input.name) el.remove()
      })
      const hidden = document.createElement("input")
      hidden.type = "hidden"
      hidden.name = name
      hidden.value = value == null || Number.isNaN(value) ? "" : String(value)
      hidden.dataset.numberToPercentageFor = input.name
      input.insertAdjacentElement("afterend", hidden)
      input.disabled = true
    })
  }
}
