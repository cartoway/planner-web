// Copyright © Cartoway
// Toggle-all checkboxes in a table + enable bulk action when any is checked.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["all", "row", "bulk"]

  toggleAll () {
    if (!this.hasAllTarget) return
    const checked = this.allTarget.checked
    this.rowTargets.forEach((box) => {
      if (box.disabled) return
      box.checked = checked
    })
    this.syncBulk()
  }

  syncBulk () {
    const any = this.rowTargets.some((box) => box.checked && !box.disabled)
    this.bulkTargets.forEach((el) => { el.disabled = !any })
  }
}
