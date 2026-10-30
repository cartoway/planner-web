// Copyright © Cartoway
// Client-side text filter for table rows (chunked so the input stays responsive).
import { Controller } from "@hotwired/stimulus"
import { scheduleListFilter } from "lib/list_filter"

export default class extends Controller {
  static targets = ["input", "row", "count"]

  connect () {
    this._cancelFilter = null
    this._textCache = new WeakMap()
    // Turbo has no after-stream-render — wrap render to recount after append/remove.
    this.boundOnBeforeStreamRender = this.onBeforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundOnBeforeStreamRender)
  }

  disconnect () {
    this._cancelFilter?.()
    this._cancelFilter = null
    document.removeEventListener("turbo:before-stream-render", this.boundOnBeforeStreamRender)
  }

  onBeforeStreamRender (event) {
    const render = event.detail.render
    event.detail.render = async (streamElement) => {
      await render(streamElement)
      this._textCache = new WeakMap()
      this.filter()
    }
  }

  filter () {
    this._cancelFilter?.()
    const q = this.hasInputTarget ? this.inputTarget.value : ""
    this._cancelFilter = scheduleListFilter({
      items: this.rowTargets,
      query: q,
      getText: (row) => {
        let text = this._textCache.get(row)
        if (text == null) {
          text = (row.textContent || "").toLowerCase()
          this._textCache.set(row, text)
        }
        return text
      },
      setVisible: (row, show) => {
        row.classList.toggle("d-none", !show)
      },
      onDone: (n) => {
        if (this.hasCountTarget) this.countTarget.textContent = String(n)
        this.dispatch("filtered", { detail: { count: n } })
      }
    })
  }
}
