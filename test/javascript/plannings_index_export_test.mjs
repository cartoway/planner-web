// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/v2/plannings_index_controller.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-plannings-index.mjs')
const source = fs.readFileSync(srcPath, 'utf8').replace(
  'import { Controller } from "@hotwired/stimulus"\n\nexport default class extends Controller {',
  'class Controller {}\n\nexport default class extends Controller {'
)
fs.writeFileSync(tmpPath, source)
const { planningExportUrl } = await import(pathToFileURL(tmpPath).href)

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
