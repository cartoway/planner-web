// Copyright © Cartoway
// Replace visit tags in bulk from the destination sidebar modal (replaces Paloma jQuery handler).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["from", "to"]

  apply (event) {
    event.preventDefault()
    const fromTags = this.selectedValues(this.hasFromTarget ? this.fromTarget : null)
    const toTags = this.selectedValues(this.hasToTarget ? this.toTarget : null)
    const visits = document.getElementById("visits")
    if (!visits || !fromTags.length) return

    visits.querySelectorAll('select[name$="[tag_ids][]"]').forEach((select) => {
      fromTags.forEach((fromId, index) => {
        const toId = toTags[index]
        if (!this.hasSelected(select, fromId)) return
        this.replaceTag(select, fromId, toId)
      })
    })
  }

  selectedValues (select) {
    if (!select) return []
    if (select.tomselect) {
      const v = select.tomselect.getValue()
      return (Array.isArray(v) ? v : [v]).filter((x) => x != null && x !== "").map(String)
    }
    return Array.from(select.selectedOptions).map((o) => o.value).filter(Boolean)
  }

  hasSelected (select, value) {
    const id = String(value)
    if (select.tomselect) {
      const v = select.tomselect.getValue()
      return (Array.isArray(v) ? v : [v]).map(String).includes(id)
    }
    return Array.from(select.selectedOptions).some((o) => o.value === id)
  }

  replaceTag (select, fromId, toId) {
    const from = String(fromId)
    const to = toId == null || toId === "" ? null : String(toId)
    if (select.tomselect) {
      let values = select.tomselect.getValue()
      values = (Array.isArray(values) ? values : [values]).map(String).filter(Boolean)
      if (!values.includes(from)) return
      values = values.filter((v) => v !== from)
      if (to && !values.includes(to)) values.push(to)
      select.tomselect.setValue(values, true)
      return
    }
    Array.from(select.options).forEach((opt) => {
      if (opt.value === from) opt.selected = false
      if (to && opt.value === to) opt.selected = true
    })
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }
}
