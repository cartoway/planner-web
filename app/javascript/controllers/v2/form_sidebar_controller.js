// Copyright © Cartoway
// V2 right column: open when destination edit form is loaded in turbo-frame#form_sidebar, close with X.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["frame", "chrome"]

  connect() {
    this.boundOnFrameLoad = this.onFrameLoad.bind(this)
    if (this.hasFrameTarget) {
      this.frameTarget.addEventListener("turbo:frame-load", this.boundOnFrameLoad)
    }
    this.refreshState()
    this.mountDestinationFormIfPresent()
  }

  disconnect() {
    if (this.hasFrameTarget) {
      this.frameTarget.removeEventListener("turbo:frame-load", this.boundOnFrameLoad)
    }
  }

  onFrameLoad() {
    this.refreshState()
    this.mountDestinationFormIfPresent()
  }

  mountDestinationFormIfPresent() {
    if (typeof window.mountV2DestinationSidebarForm !== "function" || !this.hasFrameTarget) return
    if (this.frameTarget.querySelector("#destination-form-sidebar")) {
      window.mountV2DestinationSidebarForm(this.frameTarget)
    }
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
    const sidebarForm = this.frameTarget.querySelector("#destination-form-sidebar")
    if (sidebarForm) {
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
