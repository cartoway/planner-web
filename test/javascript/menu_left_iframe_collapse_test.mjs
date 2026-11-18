// Copyright © Cartoway
// Happy-path: focusing an iframe inside .main should collapse the expanded menu-left.
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const srcPath = new URL('../../app/javascript/controllers/menu_left_controller.js', import.meta.url)
const raw = fs.readFileSync(srcPath, 'utf8')
  .replace(/import \{ Controller \} from ['"]@hotwired\/stimulus['"]/, 'class Controller {}')
  .replace(/import \{[\s\S]*?\} from ['"]lib\/menu_section_expand['"]/, '')
  .replace(/export default class extends Controller/, 'export class MenuLeftController extends Controller')

const tmpPath = path.join(os.tmpdir(), `planner-menu-left-${process.pid}.mjs`)
fs.writeFileSync(tmpPath, raw)
const { iframeFocusShouldCollapseMenu } = await import(pathToFileURL(tmpPath).href)

describe('menu-left iframe focus collapses menu', () => {
  it('detects focus inside a main iframe (jobs / performances)', () => {
    const main = {
      contains (el) { return el === iframe }
    }
    const iframe = { tagName: 'IFRAME' }
    const other = { tagName: 'DIV' }
    assert.equal(iframeFocusShouldCollapseMenu(main, iframe), true)
    assert.equal(iframeFocusShouldCollapseMenu(main, other), false)
    assert.equal(iframeFocusShouldCollapseMenu(main, null), false)
    assert.equal(iframeFocusShouldCollapseMenu(null, iframe), false)
  })
})
