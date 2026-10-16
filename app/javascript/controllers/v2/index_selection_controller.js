// Copyright © Cartoway
// Enter/exit card-index selection mode (reveals checkboxes + bulk bar).
// Compose with v2--table-selection on the same element for checkbox sync.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["root", "toggleLabel"]
  static values = {
    selectLabel: { type: String, default: "Select" },
    cancelLabel: { type: String, default: "Cancel" }
  }

  toggle () {
    if (!this.hasRootTarget) return
    const on = this.rootTarget.classList.toggle("is-selecting")
    this._setLabel(on)
    if (!on) this._clearSelection()
  }

  _setLabel (selecting) {
    if (!this.hasToggleLabelTarget) return
    this.toggleLabelTarget.textContent = selecting ? this.cancelLabelValue : this.selectLabelValue
  }

  _clearSelection () {
    this.rootTarget.querySelectorAll('[data-v2--table-selection-target="row"]').forEach((box) => {
      box.checked = false
    })
    const all = this.rootTarget.querySelector('[data-v2--table-selection-target="all"]')
    if (all) all.checked = false
    this.rootTarget.querySelectorAll('[data-v2--table-selection-target="bulk"]').forEach((el) => {
      el.disabled = true
    })
  }
}
