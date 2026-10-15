// Copyright © Cartoway
// Client-side text filter for table rows.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "row", "count"]

  connect () {
    // Turbo has no after-stream-render — wrap render to recount after append/remove.
    this.boundOnBeforeStreamRender = this.onBeforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundOnBeforeStreamRender)
  }

  disconnect () {
    document.removeEventListener("turbo:before-stream-render", this.boundOnBeforeStreamRender)
  }

  onBeforeStreamRender (event) {
    const render = event.detail.render
    event.detail.render = async (streamElement) => {
      await render(streamElement)
      this.filter()
    }
  }

  filter () {
    const q = (this.hasInputTarget ? this.inputTarget.value : "").trim().toLowerCase()
    let n = 0
    this.rowTargets.forEach((row) => {
      const show = !q || (row.textContent || "").toLowerCase().includes(q)
      row.classList.toggle("d-none", !show)
      if (show) n++
    })
    if (this.hasCountTarget) this.countTarget.textContent = String(n)
  }
}
