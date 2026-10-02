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
const { planningExportUrl } = await import(pathToFileURL(indexTmp).href)

describe('planning list export url', () => {
  it('builds an excel url from the selected ids and modal columns', () => {
    const url = planningExportUrl({
      format: 'excel',
      ids: ['4', '9'],
      columns: 'name|ref',
      skips: 'comment',
      stops: 'store|rest',
      summary: false
    })

    assert.equal(url, '/plannings.excel?stops=store%7Crest&columns=name%7Cref&ids=4%2C9&skips=comment')
  })
})

describe('planning list compare url', () => {
  it('builds a compare url from the selected ids and reference', () => {
    assert.equal(planningCompareUrl(['4', '9']), '/plannings/compare?ids=4%2C9')
    assert.equal(planningCompareUrl(['4', '9'], 9), '/plannings/compare?ids=4%2C9&ref=9')
  })
})
