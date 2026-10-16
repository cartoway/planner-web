// Copyright © Cartoway
// Fleet configs index: select-all, pointer reorder, client sort + persist.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect () {
    this.boundOnBeforeStreamRender = this.onBeforeStreamRender.bind(this)
    document.addEventListener("turbo:before-stream-render", this.boundOnBeforeStreamRender)
    const hash = window.location.hash
    if (!hash) return
    const panel = this.element.querySelector(hash)
    if (panel?.classList.contains("collapse")) this.openExclusivePanel(panel)
  }

  disconnect () {
    document.removeEventListener("turbo:before-stream-render", this.boundOnBeforeStreamRender)
    this.clearPointerListeners()
  }

  // Appended/replaced blocks with .show do not go through Bootstrap Collapse — close siblings.
  onBeforeStreamRender (event) {
    const render = event.detail.render
    event.detail.render = async (streamElement) => {
      await render(streamElement)
      const open = this.accordionCollapses().filter((el) => el.classList.contains("show"))
      if (open.length === 0) return
      this.openExclusivePanel(open[open.length - 1])
    }
  }

  accordionCollapses () {
    return Array.from(this.element.querySelectorAll("#accordion-vehicle-usage-sets .collapse"))
  }

  openExclusivePanel (panel) {
    if (!panel) return
    const target = `#${panel.id}`
    this.accordionCollapses().forEach((el) => {
      el.classList.toggle("show", el === panel)
    })
    this.element.querySelectorAll(".usage-set-toggle").forEach((btn) => {
      const open = btn.getAttribute("data-bs-target") === target
      btn.classList.toggle("collapsed", !open)
      btn.setAttribute("aria-expanded", String(open))
    })
  }

  persistOrder (list) {
    const setId = list.dataset.vehicleUsageSetId
    if (!setId) return
    const ids = Array.from(list.querySelectorAll(".vehicle-usage-card[data-vehicle-usage-id]")).map((card) => card.dataset.vehicleUsageId)
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

  // Pointer drag matches v1 jquery sortable (works for nested cards).
  pointerDown (event) {
    if (event.button !== 0) return
    const card = event.currentTarget.closest(".vehicle-usage-card[data-vehicle-usage-id]")
    const list = card?.closest(".vehicle-usages-sortable--enabled")
    if (!card || !list) return
    event.preventDefault()
    this._drag = { card, list, startY: event.clientY, moved: false }
    this._onMove = this.pointerMove.bind(this)
    this._onUp = this.pointerUp.bind(this)
    window.addEventListener("pointermove", this._onMove)
    window.addEventListener("pointerup", this._onUp)
    card.classList.add("is-dragging")
  }

  pointerMove (event) {
    if (!this._drag) return
    if (!this._drag.moved && Math.abs(event.clientY - this._drag.startY) < 3) return
    this._drag.moved = true
    const { card, list } = this._drag
    const y = event.clientY
    const others = Array.from(list.querySelectorAll(".vehicle-usage-card[data-vehicle-usage-id]")).filter((item) => item !== card)
    const next = others.find((item) => {
      const rect = item.getBoundingClientRect()
      return y < rect.top + rect.height / 2
    })
    if (next) next.before(card)
    else list.appendChild(card)
  }

  pointerUp () {
    this.clearPointerListeners()
    if (!this._drag) return
    this._drag.card.classList.remove("is-dragging")
    if (this._drag.moved) this.persistOrder(this._drag.list)
    this._drag = null
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
    const listRoot = item.closest(".vehicle-usages-list")
    const list = listRoot?.querySelector(".vehicle-usages-sortable--enabled")
    if (!list) return
    const cards = Array.from(list.querySelectorAll(".vehicle-usage-card[data-vehicle-usage-id]"))
    const mult = direction === "desc" ? -1 : 1
    cards.sort((a, b) => {
      if (field === "id") return mult * (Number(a.dataset.vehicleId) - Number(b.dataset.vehicleId))
      const av = String(field === "name" ? a.dataset.vehicleName : a.dataset.routerSort || "")
      const bv = String(field === "name" ? b.dataset.vehicleName : b.dataset.routerSort || "")
      return mult * av.localeCompare(bv, undefined, { sensitivity: "base" })
    })
    cards.forEach((card) => list.appendChild(card))
    this.persistOrder(list)
  }

  // Reveal nested vehicle checkboxes + bulk enable/disable (mirrors index Sélectionner).
  toggleVehicleSelect (event) {
    const btn = event.currentTarget
    const listRoot = btn.closest(".vehicle-usages-list")
    if (!listRoot) return
    const on = listRoot.classList.toggle("is-selecting")
    const label = btn.querySelector("[data-vehicle-select-label]")
    if (label) label.textContent = on ? (btn.dataset.cancelLabel || "Cancel") : (btn.dataset.selectLabel || "Select")
    btn.title = label?.textContent || btn.title
    if (!on) {
      listRoot.querySelectorAll(".vehicle-select").forEach((cb) => { cb.checked = false })
      const all = listRoot.querySelector(".select-unselect-all")
      if (all) all.checked = false
      const setId = listRoot.querySelector(".vehicle-usages-sortable")?.dataset.vehicleUsageSetId
      if (setId) this.syncBulk(setId)
    }
  }

  toggleAll (event) {
    const box = event.currentTarget
    const setId = box.dataset.id
    const list = this.element.querySelector(`#accordion-${setId}`)
    list?.querySelectorAll(".vehicle-select").forEach((cb) => {
      if (!cb.disabled) cb.checked = box.checked
    })
    this.syncBulk(setId)
  }

  syncRow (event) {
    const setId = event.currentTarget.closest(".vehicle-usages-sortable")?.dataset.vehicleUsageSetId
    if (setId) this.syncBulk(setId)
  }

  syncBulk (setId) {
    const list = this.element.querySelector(`#accordion-${setId}`)
    const any = Array.from(list?.querySelectorAll(".vehicle-select") || []).some((cb) => cb.checked)
    this.element.querySelectorAll(`#multiple-actions-${setId} button`).forEach((btn) => { btn.disabled = !any })
  }
}
