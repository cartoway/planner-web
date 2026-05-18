// Copyright © Cartoway
// Shows a sticky submit bar at the bottom of the sidebar when the wrapped form is dirty.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form", "bar"]

  connect() {
    if (!this.hasFormTarget || !this.hasBarTarget) return
    this.captureBaseline()
    this.boundCheck = this.checkDirty.bind(this)
    this.formTarget.addEventListener("input", this.boundCheck, { passive: true })
    this.formTarget.addEventListener("change", this.boundCheck)
  }

  disconnect() {
    if (!this.hasFormTarget) return
    this.formTarget.removeEventListener("input", this.boundCheck)
    this.formTarget.removeEventListener("change", this.boundCheck)
  }

  captureBaseline() {
    this.baseline = this.serializeForm()
    if (this.hasBarTarget) this.barTarget.classList.add("is-hidden")
  }

  serializeForm() {
    return new URLSearchParams(new FormData(this.formTarget)).toString()
  }

  checkDirty() {
    if (!this.hasBarTarget) return
    if (this.serializeForm() !== this.baseline) {
      this.barTarget.classList.remove("is-hidden")
    } else {
      this.barTarget.classList.add("is-hidden")
    }
  }
}
