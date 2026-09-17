// Copyright © Cartoway
// V2 right column: open when a form is loaded in turbo-frame#form_sidebar, close with X.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "chrome"]

  connect() {
    this.boundOnFrameLoad = this.onFrameLoad.bind(this)
    this.boundOnMainFrameLoad = this.onMainFrameLoad.bind(this)
    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("turbo:frame-load", this.boundOnFrameLoad)
    }
    this.mainFrame = document.getElementById("main")
    if (this.mainFrame) {
      this.mainFrame.addEventListener("turbo:frame-load", this.boundOnMainFrameLoad)
    }
    this.refreshState()
  }

  disconnect() {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("turbo:frame-load", this.boundOnFrameLoad)
    }
    if (this.mainFrame) {
      this.mainFrame.removeEventListener("turbo:frame-load", this.boundOnMainFrameLoad)
    }
    this.mainFrame = null
  }

  onMainFrameLoad (event) {
    if (event.target !== this.mainFrame) return
    if (!this.hasFrameTarget || !this.frameTarget.querySelector("form")) return
    this.close()
  }

  onFrameLoad() {
    this.refreshState()
  }

  close(event) {
    if (event) event.preventDefault()
    const tpl = document.getElementById("form-sidebar-placeholder-template")
    if (this.hasFrameTarget && tpl && tpl.content) {
      this.frameTarget.innerHTML = ""
      this.frameTarget.appendChild(tpl.content.cloneNode(true))
    }
    this.refreshState()
    // Not a Turbo navigation — notify listeners (e.g. destinations index position-drag teardown).
    if (this.hasFrameTarget) {
      this.frameTarget.dispatchEvent(new CustomEvent("turbo:frame-load", { bubbles: true }))
    }
  }

  refreshState() {
    if (!this.hasFrameTarget) return
    const hasForm = !!this.frameTarget.querySelector("form")
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
}
