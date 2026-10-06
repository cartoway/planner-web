// Copyright © Cartoway
// V2 right column: open when a form is loaded in turbo-frame#form_sidebar, close with X.
// Keeps the address bar on the form URL so the same sidebar can be reopened from a shared link.
import { Controller } from "@hotwired/stimulus"
import { visit } from "turbo/frame_promoted_visit"
import { formSidebarHistoryUpdate, formSidebarPageKey } from "lib/form_sidebar_history"

export default class extends Controller {
  static targets = ["frame", "chrome"]
  static values = { listUrl: String }

  connect() {
    this.boundOnFrameLoad = this.onFrameLoad.bind(this)
    this.boundOnMainFrameLoad = this.onMainFrameLoad.bind(this)
    this.boundOnPopState = this.onPopState.bind(this)
    const frame = this.frameEl()
    if (frame) frame.addEventListener("turbo:frame-load", this.boundOnFrameLoad)
    this.mainFrame = document.getElementById("main")
    if (this.mainFrame) {
      this.mainFrame.addEventListener("turbo:frame-load", this.boundOnMainFrameLoad)
    }
    window.addEventListener("popstate", this.boundOnPopState)
    this.refreshState()
    this.syncHistory()
  }

  disconnect() {
    const frame = this.frameEl()
    if (frame) frame.removeEventListener("turbo:frame-load", this.boundOnFrameLoad)
    if (this.mainFrame) {
      this.mainFrame.removeEventListener("turbo:frame-load", this.boundOnMainFrameLoad)
    }
    window.removeEventListener("popstate", this.boundOnPopState)
    this.mainFrame = null
  }

  onMainFrameLoad (event) {
    if (event.target !== this.mainFrame) return
    const frame = this.frameEl()
    if (!frame || !frame.querySelector("form")) return
    this.close()
  }

  onFrameLoad() {
    this.refreshState()
    if (this._skipNextFrameHistory) {
      this._skipNextFrameHistory = false
      return
    }
    this.syncHistory()
  }

  onPopState (event) {
    if (!this.frameEl()) return
    const loc = formSidebarPageKey(window.location.href)
    const list = formSidebarPageKey(this.listUrl())
    if (loc === list) {
      this._skipNextFrameHistory = true
      this.replaceFrameWithPlaceholder()
      this._listUrlWhileFormOpen = null
      this.refreshState()
      return
    }
    if (event.state?.formSidebar) {
      this._fromPopstate = true
      visit(window.location.href, { frame: "form_sidebar", track: false })
    }
  }

  close(event) {
    if (event) event.preventDefault()
    this.replaceFrameWithPlaceholder()
    this.refreshState()
    this.syncHistory()
    this._skipNextFrameHistory = true
    // Not a Turbo navigation — notify listeners (e.g. destinations index position-drag teardown).
    const frame = this.frameEl()
    if (frame) {
      frame.dispatchEvent(new CustomEvent("turbo:frame-load", { bubbles: true }))
    }
  }

  refreshState() {
    const frame = this.frameEl()
    if (!frame) return
    const hasForm = !!frame.querySelector("form")
    if (hasForm) {
      this.element.classList.remove("form-sidebar--collapsed", "slide-panel--collapsed")
      this.element.classList.add("form-sidebar--open")
      if (this.hasChromeTarget) this.chromeTarget.classList.remove("d-none")
    } else {
      this.element.classList.add("form-sidebar--collapsed", "slide-panel--collapsed")
      this.element.classList.remove("form-sidebar--open")
      if (this.hasChromeTarget) this.chromeTarget.classList.add("d-none")
    }
  }

  replaceFrameWithPlaceholder () {
    const frame = this.frameEl()
    const tpl = document.getElementById("form-sidebar-placeholder-template")
    if (!frame || !tpl || !tpl.content) return
    frame.removeAttribute("src")
    frame.innerHTML = ""
    frame.appendChild(tpl.content.cloneNode(true))
  }

  syncHistory () {
    const hasForm = this.hasForm()
    const frameSrc = this.frameSrc()
    if (hasForm && frameSrc) {
      const current = formSidebarPageKey(window.location.href)
      const next = formSidebarPageKey(frameSrc)
      if (current !== next && !this._listUrlWhileFormOpen) {
        this._listUrlWhileFormOpen = current
      }
    }
    const listUrl = this.listUrl()
    const update = formSidebarHistoryUpdate({
      currentHref: window.location.href,
      frameSrc,
      listUrl,
      hasForm,
      fromPopstate: this._fromPopstate
    })
    if (!hasForm) this._listUrlWhileFormOpen = null
    this._fromPopstate = false
    this.applyHistory(update, listUrl)
  }

  applyHistory (update, listUrl) {
    if (!update) return
    const state = { ...(window.history.state || {}), formSidebar: update.formSidebar, listUrl }
    if (update.formSidebar) state.turboFrameId = "form_sidebar"
    const url = `${update.url}${window.location.hash || ''}`
    if (update.type === "push") window.history.pushState(state, "", url)
    else window.history.replaceState(state, "", url)
  }

  frameEl () {
    if (this.hasFrameTarget) return this.frameTarget
    return this.element.querySelector("#form_sidebar")
  }

  hasForm () {
    const frame = this.frameEl()
    return !!(frame && frame.querySelector("form"))
  }

  frameSrc () {
    const frame = this.frameEl()
    return frame ? frame.getAttribute("src") : null
  }

  listUrl () {
    return this._listUrlWhileFormOpen || this.listUrlValue || formSidebarPageKey(window.location.href)
  }
}
