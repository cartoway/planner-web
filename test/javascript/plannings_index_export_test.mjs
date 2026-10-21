// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const compareUrlSrc = new URL('../../app/javascript/lib/planning_compare_url.js', import.meta.url)
const compareUrlTmp = path.join(os.tmpdir(), 'planner-planning-compare-url.mjs')
fs.writeFileSync(compareUrlTmp, fs.readFileSync(compareUrlSrc))
const { planningCompareUrl } = await import(pathToFileURL(compareUrlTmp).href)

const indexSrc = new URL('../../app/javascript/controllers/v2/plannings_index_controller.js', import.meta.url)
const indexTmp = path.join(os.tmpdir(), 'planner-plannings-index.mjs')
const indexSource = fs.readFileSync(indexSrc, 'utf8')
  .replace('import { Controller } from "@hotwired/stimulus"\n', 'class Controller {}\n')
  .replace('import { planningCompareUrl } from "lib/planning_compare_url"\n', 'const planningCompareUrl = () => {}\n')
fs.writeFileSync(indexTmp, indexSource)
const { planningExportDownload } = await import(pathToFileURL(indexTmp).href)

function mockDocument () {
  const forms = []
  globalThis.document = {
    querySelector: () => null,
    body: {
      appendChild (form) {
        forms.push(form)
      }
    },
    createElement (tag) {
      if (tag !== 'form' && tag !== 'input') throw new Error(`unexpected createElement(${tag})`)
      const el = {
        tagName: tag.toUpperCase(),
        style: {},
        children: [],
        appendChild (child) {
          this.children.push(child)
        },
        submit () {
          this.submitted = true
        },
        remove () {
          this.removed = true
        }
      }
      return el
    }
  }
  return forms
}

describe('planning list export download', () => {
  it('POSTs an excel form with selected ids and modal columns', () => {
    const forms = mockDocument()
    planningExportDownload({
      format: 'excel',
      ids: ['4', '9'],
      columns: 'name|ref',
      skips: 'comment',
      stops: 'store|rest',
      summary: false
    })

    assert.equal(forms.length, 1)
    const form = forms[0]
    assert.equal(form.method, 'post')
    assert.equal(form.action, '/plannings/export.excel')
    assert.equal(form.submitted, true)
    assert.equal(form.removed, true)

    const fields = Object.fromEntries(form.children.map((input) => [input.name, input.value]))
    assert.deepEqual(fields, {
      stops: 'store|rest',
      columns: 'name|ref',
      ids: '4,9',
      skips: 'comment'
    })
  })

  it('keeps the given column order in the POST body', () => {
    const forms = mockDocument()
    planningExportDownload({
      format: 'excel',
      ids: ['4'],
      columns: 'city|name|ref',
      skips: 'comment',
      stops: '',
      summary: false
    })

    const fields = Object.fromEntries(forms[0].children.map((input) => [input.name, input.value]))
    assert.equal(fields.columns, 'city|name|ref')
  })

  it('POSTs route export when routeId is set', () => {
    const forms = mockDocument()
    planningExportDownload({
      format: 'excel',
      ids: ['4'],
      columns: 'name',
      skips: '',
      stops: '',
      summary: false,
      routeId: '12'
    })

    assert.equal(forms[0].action, '/routes/12/export.excel')
  })
})

describe('planning list compare url', () => {
  it('builds a compare url from the selected ids and reference', () => {
    assert.equal(planningCompareUrl(['4', '9']), '/plannings/compare?ids=4%2C9')
    assert.equal(planningCompareUrl(['4', '9'], 9), '/plannings/compare?ids=4%2C9&ref=9')
  })
})
