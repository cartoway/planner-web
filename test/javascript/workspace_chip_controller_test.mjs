// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/v2/workspace_chip_controller.js', import.meta.url)
const raw = fs.readFileSync(srcPath, 'utf8')
  .replace(/import \{ Controller \} from "@hotwired\/stimulus"/, 'class Controller {}')
  .replace(/export default class extends Controller/, 'export default class extends Controller')

const tmpPath = path.join(os.tmpdir(), `planner-workspace-chip-${process.pid}.mjs`)
fs.writeFileSync(tmpPath, raw)
const { default: WorkspaceChipController } = await import(pathToFileURL(tmpPath).href)

function li (kind, filterLabel) {
  const el = {
    _kind: kind,
    classList: {
      _set: new Set(),
      add (c) { this._set.add(c) },
      remove (c) { this._set.delete(c) },
      contains (c) { return this._set.has(c) },
      toggle (c, on) { if (on) this._set.add(c); else this._set.delete(c) }
    },
    dataset: { filterLabel },
    textContent: filterLabel,
    matches (sel) {
      if (sel.includes('"group"') || sel.includes("='group']") || sel.includes('="group"]')) return this._kind === 'group'
      if (sel.includes('"item"') || sel.includes("='item']") || sel.includes('="item"]')) return this._kind === 'item'
      return false
    },
    nextElementSibling: null
  }
  return el
}

describe('workspace_chip_controller', () => {
  it('keeps group visible when a child user row matches the filter', () => {
    const group = li('group', 'acme logistics')
    const item = li('item', 'acme logistics alice@example.com')
    const other = li('item', 'other bob@example.com')
    group.nextElementSibling = item
    item.nextElementSibling = other

    const ctrl = Object.create(WorkspaceChipController.prototype)
    ctrl.hasFilterTarget = true
    ctrl.filterTarget = { value: 'alice' }
    ctrl.itemTargets = [item, other]
    ctrl.groupTargets = [group]
    ctrl.filter()

    assert.equal(item.classList.contains('d-none'), false)
    assert.equal(other.classList.contains('d-none'), true)
    assert.equal(group.classList.contains('d-none'), false)
  })
})
