// Copyright © Cartoway
import assert from 'node:assert/strict'
import fs from 'node:fs'
import os from 'node:os'
import path from 'node:path'
import { describe, it } from 'node:test'
import { pathToFileURL } from 'node:url'

const src = new URL('../../app/javascript/lib/form_sidebar_history.js', import.meta.url)
const tmp = path.join(os.tmpdir(), 'planner-form-sidebar-history.mjs')
fs.writeFileSync(tmp, fs.readFileSync(src))
const {
  formSidebarAdoptMainNavigation,
  formSidebarHistoryUpdate,
  formSidebarPageKey,
  formSidebarShouldGoBackOnClose
} = await import(pathToFileURL(tmp).href)

describe('form sidebar history', () => {
  it('pushes the form url when the sidebar opens from the list', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations?page=2',
      frameSrc: '/destinations/42/edit',
      listUrl: '/destinations?page=2',
      hasForm: true
    })
    assert.deepEqual(update, { type: 'push', url: '/destinations/42/edit', formSidebar: true })
  })

  it('does not push when the address bar already has the form url', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations/42/edit',
      frameSrc: '/destinations/42/edit',
      listUrl: '/destinations',
      hasForm: true
    })
    assert.equal(update, null)
  })

  it('replaces the address bar with the list url when the form closes without history.back', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations/42/edit',
      frameSrc: null,
      listUrl: '/destinations?page=2',
      hasForm: false
    })
    assert.deepEqual(update, { type: 'replace', url: '/destinations?page=2', formSidebar: false })
  })

  it('goes back on close when the current history entry is a form-sidebar push', () => {
    assert.equal(formSidebarShouldGoBackOnClose({ formSidebar: true }), true)
    assert.equal(formSidebarShouldGoBackOnClose({ formSidebar: false }), false)
    assert.equal(formSidebarShouldGoBackOnClose(null), false)
  })

  it('ignores history updates triggered by popstate', () => {
    const update = formSidebarHistoryUpdate({
      currentHref: 'http://example.test/destinations',
      frameSrc: '/destinations/42/edit',
      listUrl: '/destinations',
      hasForm: true,
      fromPopstate: true
    })
    assert.equal(update, null)
  })

  it('builds a path+query key', () => {
    assert.equal(formSidebarPageKey('http://example.test/destinations/42/edit?include_past=1'), '/destinations/42/edit?include_past=1')
  })

  it('adopts main frame src as list url and clears form-sidebar history markers', () => {
    const adopted = formSidebarAdoptMainNavigation({
      mainSrc: 'http://example.test/stores',
      currentHref: 'http://example.test/destinations/42/edit',
      historyState: { formSidebar: true, turboFrameId: 'form_sidebar', listUrl: '/destinations', turbo: { x: 1 } }
    })
    assert.equal(adopted.listUrl, '/stores')
    assert.equal(adopted.state.listUrl, '/stores')
    assert.equal(adopted.state.formSidebar, undefined)
    assert.equal(adopted.state.turboFrameId, undefined)
    assert.deepEqual(adopted.state.turbo, { x: 1 })
  })
})
