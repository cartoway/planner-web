// Copyright © Cartoway
// Keep in sync with app/javascript/controllers/v2/visit_new_controller.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

function nextVisitIndex (fieldsets) {
  let max = 0
  fieldsets.forEach((fieldset) => {
    const name = fieldset.querySelector('[name*="[visits_attributes]"]')?.name
    const match = name?.match(/\[visits_attributes\]\[(\d+)\]/)
    if (match) max = Math.max(max, Number(match[1]))
  })
  return max + 1
}

function reindexTemplate (html, index) {
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

function fieldsetStub (index) {
  return {
    querySelector () {
      return { name: `destination[visits_attributes][${index}][id]` }
    }
  }
}

describe('nextVisitIndex', () => {
  it('returns 1 when there are no fieldsets', () => {
    assert.equal(nextVisitIndex([]), 1)
  })

  it('returns max nested index plus one including gaps', () => {
    assert.equal(nextVisitIndex([fieldsetStub(1), fieldsetStub(3)]), 4)
  })
})

describe('reindexTemplate', () => {
  it('rewrites legend and nested attribute index', () => {
    const html = [
      '<a data-bs-target="#collapseVisit0" aria-controls="collapseVisit0"></a>',
      '<span>Visite #0</span>',
      '<div id="collapseVisit0"></div>',
      '<input name="destination[visits_attributes][0][ref]" id="destination_visits_attributes_0_ref">',
      '<input id="visit_priority_i0" list="visit_priority_i0_ticks">'
    ].join('')

    const out = reindexTemplate(html, 4)

    assert.match(out, /Visite #4/)
    assert.match(out, /#collapseVisit_new_4/)
    assert.match(out, /collapseVisit_new_4/)
    assert.match(out, /destination\[visits_attributes\]\[4\]\[ref\]/)
    assert.match(out, /destination_visits_attributes_4_ref/)
    assert.match(out, /visit_priority_i4/)
    assert.doesNotMatch(out, /Visite #0/)
    assert.doesNotMatch(out, /collapseVisit0/)
  })
})
