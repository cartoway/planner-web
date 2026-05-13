// Copyright © Cartoway
// V2 layout: same behaviour as legacy application.js — expand .menu-left (.open) on any click inside the sidebar.
// Use capture phase so Bootstrap collapse / dropdown handlers that stopPropagation still allow the menu to widen.

import { Controller } from '@hotwired/stimulus'

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
      this.sidebar.querySelectorAll('.menu-content.collapse.show').forEach((el) => {
        el.classList.remove('show')
      })
    }

    this._onCollapseShow = (ev) => {
      const panel = ev.target.closest && ev.target.closest('.menu-content.collapse')
      if (!panel) return
      this.sidebar.querySelectorAll('.menu-content.collapse.show').forEach((el) => {
        if (el !== panel) el.classList.remove('show')
      })
    }

    this.element.addEventListener('click', this._openSidebarCapture, this._captureOpts)
    this.main.addEventListener('click', this._closeSidebar)
    this.sidebar.addEventListener('show.bs.collapse', this._onCollapseShow)
  }

  disconnect () {
    if (this.element && this._openSidebarCapture && this._captureOpts) {
      this.element.removeEventListener('click', this._openSidebarCapture, this._captureOpts)
    }
    if (this.main && this._closeSidebar) {
      this.main.removeEventListener('click', this._closeSidebar)
    }
    if (this.sidebar && this._onCollapseShow) {
      this.sidebar.removeEventListener('show.bs.collapse', this._onCollapseShow)
    }
  }
}
