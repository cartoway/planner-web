// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/v2/transfer_list_controller.js', import.meta.url)
const tmpPath = path.join(os.tmpdir(), 'planner-transfer-list.mjs')
const source = fs.readFileSync(srcPath, 'utf8').replace(
  'import { Controller } from "@hotwired/stimulus"\n\nconst ITEM_SELECTOR = ".transfer-list-item"\n\nexport default class extends Controller {',
  'class Controller {}\n\nconst ITEM_SELECTOR = ".transfer-list-item"\n\nexport default class extends Controller {'
)
fs.writeFileSync(tmpPath, source)
const { listValues, nextColumnKey } = await import(pathToFileURL(tmpPath).href)

describe('transfer list values', () => {
  it('reads data-value from transfer-list items', () => {
    const list = {
      querySelectorAll () {
        return [
          { dataset: { value: 'name' } },
          { dataset: { value: 'ref' } },
          { dataset: { value: '' } }
        ]
      }
    }

    assert.deepEqual(listValues(list), ['name', 'ref'])
  })

  it('cycles to the next column key for 3-column layouts', () => {
    const columns = [
      { key: 'active' },
      { key: 'disabled' },
      { key: 'inactive' }
    ]

    assert.equal(nextColumnKey(columns, 'active'), 'disabled')
    assert.equal(nextColumnKey(columns, 'disabled'), 'inactive')
    assert.equal(nextColumnKey(columns, 'inactive'), 'active')
  })
})
