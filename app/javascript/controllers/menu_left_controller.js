// Copyright © Cartoway
// V2 layout: expand .menu-left (.open) on any click inside the sidebar.
// Use capture phase so Bootstrap collapse / dropdown handlers that stopPropagation still allow the menu to widen.
// Mega-accordion: opening a collapse in #accordion-menu or #menu-settings swaps the other block for a burger.

import { Controller } from '@hotwired/stimulus'
import {
  applySectionExpand,
  clearSectionExpand,
  sectionForCollapse,
  syncExpandAfterHide
} from 'lib/menu_section_expand'

const OPEN_COLLAPSE = '.menu-content.collapse.show'

export default class extends Controller {
  connect () {
    this.sidebar = this.element.querySelector('.menu-left')
    this.main = this.element.querySelector('.main')
    if (!this.sidebar || !this.main) return

    this._captureOpts = { capture: true }

    // Any click whose target lies inside .menu-left (any zone) → expand, like v1 menuLeft.on("click", ...)
    this._openSidebarCapture = (e) => {
      if (this.sidebar.contains(e.target)) this.sidebar.classList.add('open')
    }

    this._closeSidebar = () => {
      this.sidebar.classList.remove('open')
      this._hideAllCollapses()
      clearSectionExpand(this.sidebar)
    }

    this._onCollapseShow = (ev) => {
      const panel = ev.target
      if (!panel || !panel.classList || !panel.classList.contains('collapse')) return
      this.sidebar.querySelectorAll(OPEN_COLLAPSE).forEach((el) => {
        if (el !== panel) el.classList.remove('show')
      })
      // Remember section while opening so a sibling hide (data-bs-parent) cannot clear it.
      this._expandOnShow = sectionForCollapse(panel)
      if (this._expandOnShow) applySectionExpand(this.sidebar, this._expandOnShow)
    }

    this._onCollapseShown = () => {
      this._expandOnShow = null
    }

    this._onCollapseHide = (ev) => {
      // Defer: sibling hide runs during another panel's show; keep expand if opening.
      clearTimeout(this._syncHideTimer)
      const hiding = ev.target
      this._syncHideTimer = setTimeout(() => {
        if (this._expandOnShow) {
          applySectionExpand(this.sidebar, this._expandOnShow)
          return
        }
        syncExpandAfterHide(this.sidebar, OPEN_COLLAPSE, hiding)
      }, 0)
    }

    this.element.addEventListener('click', this._openSidebarCapture, this._captureOpts)
    this.main.addEventListener('click', this._closeSidebar)
    this.sidebar.addEventListener('show.bs.collapse', this._onCollapseShow)
    this.sidebar.addEventListener('shown.bs.collapse', this._onCollapseShown)
    this.sidebar.addEventListener('hide.bs.collapse', this._onCollapseHide)
  }

  disconnect () {
    clearTimeout(this._syncHideTimer)
    if (this.element && this._openSidebarCapture && this._captureOpts) {
      this.element.removeEventListener('click', this._openSidebarCapture, this._captureOpts)
    }
    if (this.main && this._closeSidebar) {
      this.main.removeEventListener('click', this._closeSidebar)
    }
    if (this.sidebar) {
      if (this._onCollapseShow) this.sidebar.removeEventListener('show.bs.collapse', this._onCollapseShow)
      if (this._onCollapseShown) this.sidebar.removeEventListener('shown.bs.collapse', this._onCollapseShown)
      if (this._onCollapseHide) this.sidebar.removeEventListener('hide.bs.collapse', this._onCollapseHide)
    }
  }

  restoreCompact (event) {
    if (event) event.preventDefault()
    this._hideAllCollapses()
    clearSectionExpand(this.sidebar)
  }

  _hideAllCollapses () {
    if (!this.sidebar) return
    this.sidebar.querySelectorAll(OPEN_COLLAPSE).forEach((el) => {
      el.classList.remove('show')
    })
  }
}
