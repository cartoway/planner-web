// Copyright © Cartoway
// Searchable checklist dropdown: filter, max-active, reset defaults, count sync.
// Dispatches `searchable-checklist-dropdown:change` after checklist mutations.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "count", "search", "option", "resetDefaults"]
  static values = {
    maxActive: { type: Number, default: 8 },
    defaultActive: { type: Array, default: [] }
  }

  connect() {
    this.syncDisabledState()
  }

  change(event) {
    const checkbox = event.target
    if (!(checkbox instanceof HTMLInputElement) || checkbox.type !== "checkbox") return

    if (checkbox.checked && this.checkedCount() > this.maxActiveValue) {
      checkbox.checked = false
      this.syncDisabledState()
      return
    }

    this.syncDisabledState()
    this.dispatchChange()
  }

  filter() {
    const query = this.hasSearchTarget ? this.searchTarget.value.trim().toLowerCase() : ""
    this.optionTargets.forEach((option) => {
      const label = option.dataset.filterLabel || ""
      option.hidden = query.length > 0 && !label.includes(query)
    })
  }

  resetDefaults(event) {
    event.preventDefault()
    if (this.isAtDefaults()) return

    const defaults = new Set(this.defaultActiveValue.map(String))
    this.checkboxes().forEach((checkbox) => {
      checkbox.disabled = false
      checkbox.checked = defaults.has(checkbox.value)
    })
    this.syncDisabledState()
    this.dispatchChange()
  }

  checkboxes() {
    if (!this.hasFormTarget) return []
    return this.formTarget.querySelectorAll('input[type="checkbox"]')
  }

  checkedValues() {
    return [...this.checkboxes()].filter((checkbox) => checkbox.checked).map((checkbox) => checkbox.value)
  }

  checkedCount() {
    return this.checkedValues().length
  }

  isAtDefaults() {
    const defaults = this.defaultActiveValue.map(String)
    const checked = this.checkedValues()
    if (checked.length !== defaults.length) return false
    const checkedSet = new Set(checked)
    return defaults.every((id) => checkedSet.has(id))
  }

  syncDisabledState() {
    const checked = this.checkedCount()
    const atMax = checked >= this.maxActiveValue
    this.checkboxes().forEach((checkbox) => {
      checkbox.disabled = atMax && !checkbox.checked
    })
    if (this.hasCountTarget) {
      this.countTarget.textContent = `${checked} / ${this.maxActiveValue}`
    }
    if (this.hasResetDefaultsTarget) {
      this.resetDefaultsTarget.disabled = this.isAtDefaults()
    }
  }

  dispatchChange() {
    this.element.dispatchEvent(
      new CustomEvent("searchable-checklist-dropdown:change", {
        bubbles: true,
        detail: {
          checkedValues: this.checkedValues(),
          checkedCount: this.checkedCount()
        }
      })
    )
  }
}
