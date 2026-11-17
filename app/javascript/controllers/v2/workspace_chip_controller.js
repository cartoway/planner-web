// Copyright © Cartoway
// Floating workspace chip: client-side filter for long membership lists.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["filter", "item", "group"]
  static values = { filterThreshold: { type: Number, default: 5 } }

  filter () {
    const q = (this.hasFilterTarget ? this.filterTarget.value : "").trim().toLowerCase()
    this.itemTargets.forEach((item) => {
      const label = (item.dataset.filterLabel || item.textContent || "").toLowerCase()
      item.classList.toggle("d-none", q !== "" && !label.includes(q))
    })
    this.groupTargets.forEach((group) => {
      const groupLabel = (group.dataset.filterLabel || "").toLowerCase()
      const groupMatch = q !== "" && groupLabel.includes(q)
      let anyVisibleChild = false
      let el = group.nextElementSibling
      while (el && !el.matches('[data-v2--workspace-chip-target="group"]')) {
        if (el.matches('[data-v2--workspace-chip-target="item"]') && !el.classList.contains("d-none")) {
          anyVisibleChild = true
          break
        }
        el = el.nextElementSibling
      }
      // Show group when its name matches, or when at least one user row stays visible.
      if (groupMatch && q !== "") {
        el = group.nextElementSibling
        while (el && !el.matches('[data-v2--workspace-chip-target="group"]')) {
          if (el.matches('[data-v2--workspace-chip-target="item"]')) el.classList.remove("d-none")
          el = el.nextElementSibling
        }
        group.classList.remove("d-none")
      } else {
        group.classList.toggle("d-none", q !== "" && !anyVisibleChild)
      }
    })
  }
}
