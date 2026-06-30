// Copyright © Cartoway
// Expand/collapse all visit fieldsets in the destination form (v2 sidebar).
// Legacy `destinations.js` is not loaded on the v2 importmap entry; this replaces the #visits-expand jQuery handler.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  /** When false, next click hides all panels; when true, next click shows all (initial: all shown on load). */
  static values = {
    nextShow: { type: Boolean, default: false }
  }

  toggleAll (event) {
    event.preventDefault()
    const collapses = this.element.querySelectorAll(".visit-fieldset .collapse")
    if (!collapses.length) return

    const showNext = this.nextShowValue
    this.nextShowValue = !this.nextShowValue

    collapses.forEach((el) => {
      if (typeof bootstrap !== "undefined" && bootstrap.Collapse) {
        const inst = bootstrap.Collapse.getOrCreateInstance(el, { toggle: false })
        if (showNext) inst.show()
        else inst.hide()
      } else {
        el.classList.toggle("show", showNext)
      }
    })

    this.element.querySelectorAll("fieldset.visit-fieldset").forEach((fs) => {
      const collapse = fs.querySelector(".collapse")
      const trigger = fs.querySelector(".accordion-toggle")
      if (!collapse || !trigger) return
      const shown = collapse.classList.contains("show")
      trigger.classList.toggle("collapsed", !shown)
      trigger.setAttribute("aria-expanded", shown ? "true" : "false")
    })
  }
}
