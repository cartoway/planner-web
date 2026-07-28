// Copyright © Cartoway
// Append an empty nested visit fieldset client-side (v1 parity: not persisted until destination save).
import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['template', 'headerTemplate']

  add (event) {
    event.preventDefault()

    const visits = document.getElementById('visits')
    if (!visits || !this.hasTemplateTarget) return

    const existing = visits.querySelectorAll('fieldset.visit-fieldset')
    const nextIndex = this._nextVisitIndex(existing)
    const html = this._reindexTemplate(this.templateTarget.innerHTML, nextIndex)

    if (existing.length === 1 && this.hasHeaderTemplateTarget && !visits.querySelector('#visits-header')) {
      visits.insertAdjacentHTML('afterbegin', this.headerTemplateTarget.innerHTML)
    }

    visits.insertAdjacentHTML('beforeend', html)

    const fieldset = visits.querySelector('fieldset.visit-fieldset:last-of-type')
    const listCtrl = this.application.getControllerForElementAndIdentifier(visits, 'v2--visit-list')
    listCtrl?.revealElement(fieldset)

    document.getElementById('destination-form-sidebar')
      ?.dispatchEvent(new Event('input', { bubbles: true }))
  }

  // Max nested-attributes index already in the form + 1 (gaps after removals).
  _nextVisitIndex (fieldsets) {
    let max = 0
    fieldsets.forEach((fieldset) => {
      const name = fieldset.querySelector('[name*="[visits_attributes]"]')?.name
      const match = name?.match(/\[visits_attributes\]\[(\d+)\]/)
      if (match) max = Math.max(max, Number(match[1]))
    })
    return max + 1
  }

  _reindexTemplate (html, index) {
    const collapseId = `collapseVisit_new_${index}`
    return html
      .replace(/#collapseVisit0/g, `#${collapseId}`)
      .replace(/collapseVisit0/g, collapseId)
      .replace(/#0/g, `#${index}`)
      .replace(/isit0/g, `isit${index}`)
      .replace(/visit_priority_i0/g, `visit_priority_i${index}`)
      .replace(/visit_priority_i0_ticks/g, `visit_priority_i${index}_ticks`)
      .replace(/destination([\[_])visits([^0]+)0([\]_])/g, `destination$1visits$2${index}$3`)
  }
}
