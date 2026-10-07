// Copyright © Cartoway
// Keep in sync with app/javascript/lib/menu_section_expand.js
import assert from 'node:assert/strict'
import { describe, it } from 'node:test'

const PLAN_EXPANDED = 'menu-section-plan-expanded'
const SETTINGS_EXPANDED = 'menu-section-settings-expanded'
const EXPAND_CLASSES = [PLAN_EXPANDED, SETTINGS_EXPANDED]

function sectionForCollapse (el) {
  if (!el || !el.closest) return null
  if (el.closest('#menu-settings')) return 'settings'
  if (el.closest('#accordion-menu')) return 'plan'
  return null
}

function expandClassFor (section) {
  if (section === 'settings') return SETTINGS_EXPANDED
  if (section === 'plan') return PLAN_EXPANDED
  return null
}

function applySectionExpand (menuLeft, section) {
  if (!menuLeft || !menuLeft.classList) return
  EXPAND_CLASSES.forEach((name) => menuLeft.classList.remove(name))
  const cls = expandClassFor(section)
  if (cls) menuLeft.classList.add(cls)
}

function clearSectionExpand (menuLeft) {
  if (!menuLeft || !menuLeft.classList) return
  EXPAND_CLASSES.forEach((name) => menuLeft.classList.remove(name))
}

function sectionHasOpenCollapse (root, openSelector, exceptEl) {
  if (!root || !root.querySelectorAll) return false
  return Array.from(root.querySelectorAll(openSelector)).some((el) => el !== exceptEl)
}

function syncExpandAfterHide (menuLeft, openSelector, hidingEl) {
  if (!menuLeft) return
  const planOpen = sectionHasOpenCollapse(menuLeft.querySelector('#accordion-menu'), openSelector, hidingEl)
  const settingsOpen = sectionHasOpenCollapse(menuLeft.querySelector('#menu-settings'), openSelector, hidingEl)
  if (planOpen) applySectionExpand(menuLeft, 'plan')
  else if (settingsOpen) applySectionExpand(menuLeft, 'settings')
  else clearSectionExpand(menuLeft)
}

function fakeEl (matches) {
  return {
    closest (sel) {
      return matches[sel] ? this : null
    }
  }
}

function fakeMenuLeft () {
  const classes = new Set()
  const planPanels = []
  const settingsPanels = []
  const roots = {
    '#accordion-menu': {
      querySelectorAll: (sel) => (sel.includes('show') || sel.includes('in') ? planPanels.slice() : [])
    },
    '#menu-settings': {
      querySelectorAll: (sel) => (sel.includes('show') || sel.includes('in') ? settingsPanels.slice() : [])
    }
  }
  return {
    planPanels,
    settingsPanels,
    classList: {
      add (name) { classes.add(name) },
      remove (name) { classes.delete(name) },
      contains (name) { return classes.has(name) }
    },
    querySelector (sel) {
      return roots[sel] || null
    },
    classes
  }
}

describe('menu section expand (mega-accordion burger)', () => {
  it('maps collapse location to plan or settings', () => {
    assert.equal(sectionForCollapse(fakeEl({ '#menu-settings': true })), 'settings')
    assert.equal(sectionForCollapse(fakeEl({ '#accordion-menu': true })), 'plan')
    assert.equal(sectionForCollapse(fakeEl({})), null)
    assert.equal(sectionForCollapse(null), null)
  })

  it('applies and clears expand classes on the menu', () => {
    const menu = fakeMenuLeft()
    assert.equal(expandClassFor('plan'), PLAN_EXPANDED)
    assert.equal(expandClassFor('settings'), SETTINGS_EXPANDED)

    applySectionExpand(menu, 'plan')
    assert.equal(menu.classes.has(PLAN_EXPANDED), true)
    assert.equal(menu.classes.has(SETTINGS_EXPANDED), false)

    applySectionExpand(menu, 'settings')
    assert.equal(menu.classes.has(PLAN_EXPANDED), false)
    assert.equal(menu.classes.has(SETTINGS_EXPANDED), true)

    clearSectionExpand(menu)
    assert.equal(menu.classes.has(PLAN_EXPANDED), false)
    assert.equal(menu.classes.has(SETTINGS_EXPANDED), false)
  })

  it('restores compact when no section has an open collapse', () => {
    const menu = fakeMenuLeft()
    applySectionExpand(menu, 'plan')
    syncExpandAfterHide(menu, '.menu-content.collapse.show')
    assert.equal(menu.classes.has(PLAN_EXPANDED), false)
  })

  it('restores compact when the last open submenu starts hiding', () => {
    const menu = fakeMenuLeft()
    const panel = { id: 'plannings' }
    menu.planPanels.push(panel)
    applySectionExpand(menu, 'plan')
    assert.equal(menu.classes.has(PLAN_EXPANDED), true)

    syncExpandAfterHide(menu, '.menu-content.collapse.show', panel)
    assert.equal(menu.classes.has(PLAN_EXPANDED), false)
    assert.equal(menu.classes.has(SETTINGS_EXPANDED), false)
  })

  it('keeps plan expanded while a plan collapse stays open', () => {
    const menu = fakeMenuLeft()
    const open = { id: 'open' }
    const hiding = { id: 'hiding' }
    menu.planPanels.push(open, hiding)
    syncExpandAfterHide(menu, '.menu-content.collapse.show', hiding)
    assert.equal(menu.classes.has(PLAN_EXPANDED), true)
    assert.equal(sectionHasOpenCollapse(menu.querySelector('#accordion-menu'), '.menu-content.collapse.show', hiding), true)
  })
})
