// Copyright © Cartoway
// Fleet configs index: select-all, pointer reorder, client sort + persist.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect () {
    const hash = window.location.hash
    if (!hash) return
    const panel = this.element.querySelector(hash)
    if (!panel || !panel.classList.contains("collapse")) return
    this.element.querySelectorAll("table#accordion-vehicle-usage-sets .collapse.show").forEach((el) => {
      if (el !== panel) el.classList.remove("show")
    })
    panel.classList.add("show")
    this.element.querySelectorAll(".usage-set-toggle").forEach((btn) => {
      const open = btn.getAttribute("data-bs-target") === hash
      btn.classList.toggle("collapsed", !open)
      btn.setAttribute("aria-expanded", String(open))
    })
  }

  persistOrder (tbody) {
    const setId = tbody.dataset.vehicleUsageSetId
    if (!setId) return
    const ids = Array.from(tbody.querySelectorAll("tr[data-vehicle-usage-id]")).map((tr) => tr.dataset.vehicleUsageId)
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    fetch(`/vehicle_usage_sets/${setId}/reorder_vehicle_usages`, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": token || ""
      },
      body: JSON.stringify({ vehicle_usage_ids: ids }),
      credentials: "same-origin"
    })
  }

  // HTML5 DnD on nested <tr> is unreliable; pointer drag matches v1 jquery sortable.
  pointerDown (event) {
    if (event.button !== 0) return
    const row = event.currentTarget.closest("tr[data-vehicle-usage-id]")
    const tbody = row?.closest("tbody.vehicle-usages-sortable--enabled")
    if (!row || !tbody) return
    event.preventDefault()
    this._drag = { row, tbody, startY: event.clientY, moved: false }
    this._onMove = this.pointerMove.bind(this)
    this._onUp = this.pointerUp.bind(this)
    window.addEventListener("pointermove", this._onMove)
    window.addEventListener("pointerup", this._onUp)
    row.classList.add("is-dragging")
  }

  pointerMove (event) {
    if (!this._drag) return
    if (!this._drag.moved && Math.abs(event.clientY - this._drag.startY) < 3) return
    this._drag.moved = true
    const { row, tbody } = this._drag
    const y = event.clientY
    const others = Array.from(tbody.querySelectorAll("tr[data-vehicle-usage-id]")).filter((item) => item !== row)
    const next = others.find((item) => {
      const rect = item.getBoundingClientRect()
      return y < rect.top + rect.height / 2
    })
    if (next) next.before(row)
    else tbody.appendChild(row)
  }

  pointerUp () {
    this.clearPointerListeners()
    if (!this._drag) return
    this._drag.row.classList.remove("is-dragging")
    if (this._drag.moved) this.persistOrder(this._drag.tbody)
    this._drag = null
  }

  disconnect () {
    this.clearPointerListeners()
  }

  clearPointerListeners () {
    if (this._onMove) window.removeEventListener("pointermove", this._onMove)
    if (this._onUp) window.removeEventListener("pointerup", this._onUp)
    this._onMove = null
    this._onUp = null
  }

  sort (event) {
    event.preventDefault()
    const item = event.currentTarget
    const field = item.dataset.sortField
    const direction = item.dataset.sortDirection
    const table = item.closest("table")
    const tbody = table?.querySelector("tbody.vehicle-usages-sortable--enabled")
    if (!tbody) return
    const rows = Array.from(tbody.querySelectorAll("tr[data-vehicle-usage-id]"))
    const mult = direction === "desc" ? -1 : 1
    rows.sort((a, b) => {
      if (field === "id") return mult * (Number(a.dataset.vehicleId) - Number(b.dataset.vehicleId))
      const av = String(field === "name" ? a.dataset.vehicleName : a.dataset.routerSort || "")
      const bv = String(field === "name" ? b.dataset.vehicleName : b.dataset.routerSort || "")
      return mult * av.localeCompare(bv, undefined, { sensitivity: "base" })
    })
    rows.forEach((row) => tbody.appendChild(row))
    this.persistOrder(tbody)
  }

  toggleAll (event) {
    const box = event.currentTarget
    const setId = box.dataset.id
    const table = this.element.querySelector(`#accordion-${setId}`)
    table?.querySelectorAll(".vehicle-select").forEach((cb) => {
      if (!cb.disabled) cb.checked = box.checked
    })
    this.syncBulk(setId)
  }

  syncRow (event) {
    const setId = event.currentTarget.closest("tbody")?.dataset.vehicleUsageSetId
    if (setId) this.syncBulk(setId)
  }

  syncBulk (setId) {
    const table = this.element.querySelector(`#accordion-${setId}`)
    const any = Array.from(table?.querySelectorAll(".vehicle-select") || []).some((cb) => cb.checked)
    this.element.querySelectorAll(`#multiple-actions-${setId} button`).forEach((btn) => { btn.disabled = !any })
  }
}
