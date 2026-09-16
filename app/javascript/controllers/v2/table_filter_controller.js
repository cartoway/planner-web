// Copyright © Cartoway
// Client-side text filter for table rows.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row", "count"]

  filter () {
    const q = (this.hasInputTarget ? this.inputTarget.value : "").trim().toLowerCase()
    let n = 0
    this.rowTargets.forEach((row) => {
      const show = !q || (row.textContent || "").toLowerCase().includes(q)
      row.classList.toggle("d-none", !show)
      if (show) n++
    })
    if (this.hasCountTarget) this.countTarget.textContent = String(n)
  }
}
