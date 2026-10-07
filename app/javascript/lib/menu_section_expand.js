// Copyright © Cartoway
// Mega-accordion: when a collapse opens in #accordion-menu or #menu-settings,
// the other block is replaced by a burger; burger restores compact layout.

export const PLAN_EXPANDED = 'menu-section-plan-expanded'
export const SETTINGS_EXPANDED = 'menu-section-settings-expanded'
export const EXPAND_CLASSES = [PLAN_EXPANDED, SETTINGS_EXPANDED]

export function sectionForCollapse (el) {
  if (!el || !el.closest) return null
  if (el.closest('#menu-settings')) return 'settings'
  if (el.closest('#accordion-menu')) return 'plan'
  return null
}

export function expandClassFor (section) {
  if (section === 'settings') return SETTINGS_EXPANDED
  if (section === 'plan') return PLAN_EXPANDED
  return null
}

export function applySectionExpand (menuLeft, section) {
  if (!menuLeft || !menuLeft.classList) return
  EXPAND_CLASSES.forEach((name) => menuLeft.classList.remove(name))
  const cls = expandClassFor(section)
  if (cls) menuLeft.classList.add(cls)
}

export function clearSectionExpand (menuLeft) {
  if (!menuLeft || !menuLeft.classList) return
  EXPAND_CLASSES.forEach((name) => menuLeft.classList.remove(name))
}

export function sectionHasOpenCollapse (root, openSelector, exceptEl) {
  if (!root || !root.querySelectorAll) return false
  return Array.from(root.querySelectorAll(openSelector)).some((el) => el !== exceptEl)
}

// Call on hide.bs.collapse (pass event.target as hidingEl) so compact menus
// restore as soon as the last submenu starts closing — don't wait for hidden.
export function syncExpandAfterHide (menuLeft, openSelector, hidingEl) {
  if (!menuLeft) return
  const planOpen = sectionHasOpenCollapse(menuLeft.querySelector('#accordion-menu'), openSelector, hidingEl)
  const settingsOpen = sectionHasOpenCollapse(menuLeft.querySelector('#menu-settings'), openSelector, hidingEl)
  if (planOpen) applySectionExpand(menuLeft, 'plan')
  else if (settingsOpen) applySectionExpand(menuLeft, 'settings')
  else clearSectionExpand(menuLeft)
}
