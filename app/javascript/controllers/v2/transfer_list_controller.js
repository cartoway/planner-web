// Copyright © Cartoway
// Shared multi-column transfer list (2+ columns), same idea as ActiveInactiveDragDrop.
import { Controller } from "@hotwired/stimulus"

const ITEM_SELECTOR = ".transfer-list-item"

export default class extends Controller {
  static targets = ["list"]
  static values = {
    showOrder: { type: Boolean, default: true }
  }

  loadFromTemplate (template) {
    if (!template || !this.hasListTarget) return
    this.listTargets.forEach((list) => list.replaceChildren())
    template.content.querySelectorAll(ITEM_SELECTOR).forEach((node) => {
      const item = this.prepareItem(node.cloneNode(true))
      const list = this.listFor(item.dataset.zone) || this.listTargets[0]
      this.applyListState(item, list)
      list.appendChild(item)
    })
    this.refreshOrders()
  }

  prepareItem (item) {
    item.setAttribute("draggable", "true")
    item.dataset.action = "dragstart->v2--transfer-list#dragStart dragend->v2--transfer-list#dragEnd"
    return item
  }

  toggleItem (event) {
    event.preventDefault()
    event.stopPropagation()
    const item = event.currentTarget.closest(ITEM_SELECTOR)
    if (!item) return
    const from = item.parentElement
    const to = this.toggleDestination(from)
    if (to) this.moveItem(item, to)
  }

  transferAll (event) {
    event.preventDefault()
    const from = this.listFor(event.currentTarget.dataset.from)
    const to = this.listFor(event.currentTarget.dataset.to)
    if (!from || !to || from === to) return
    this.moveAll(from, to)
  }

  moveAll (from, to) {
    ;[...from.querySelectorAll(ITEM_SELECTOR)].forEach((item) => this.moveItem(item, to, false))
    this.refreshOrders()
  }

  moveItem (item, list, refresh = true) {
    list.appendChild(item)
    this.applyListState(item, list)
    if (refresh) this.refreshOrders()
  }

  applyListState (item, list) {
    item.dataset.zone = list.dataset.columnKey || ""
    item.classList.toggle("inactive", list.dataset.inactive === "true")
  }

  toggleDestination (fromList) {
    const explicit = fromList?.dataset.toggleTo
    if (explicit) return this.listFor(explicit)
    const index = this.listTargets.indexOf(fromList)
    if (index < 0) return null
    return this.listTargets[(index + 1) % this.listTargets.length]
  }

  listFor (key) {
    if (!key) return null
    return this.listTargets.find((list) => list.dataset.columnKey === key) || null
  }

  dragStart (event) {
    if (event.target.closest(".item-toggle-btn")) {
      event.preventDefault()
      return
    }
    this.dragItem = event.currentTarget
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.value || "")
    event.currentTarget.classList.add("is-dragging")
  }

  dragEnd (event) {
    event.currentTarget.classList.remove("is-dragging")
    this.dragItem = null
  }

  dragOver (event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
    if (!this.dragItem) return
    const list = event.currentTarget
    const after = itemAfter(list, event.clientY)
    if (after == null) list.appendChild(this.dragItem)
    else list.insertBefore(this.dragItem, after)
  }

  drop (event) {
    event.preventDefault()
    if (!this.dragItem) return
    this.moveItem(this.dragItem, event.currentTarget)
  }

  refreshOrders () {
    if (!this.showOrderValue) {
      this.listTargets.forEach((list) => {
        list.querySelectorAll(`${ITEM_SELECTOR} .item-order`).forEach((order) => { order.textContent = "" })
      })
      return
    }
    this.listTargets.forEach((list) => {
      const inactive = list.dataset.inactive === "true"
      list.querySelectorAll(ITEM_SELECTOR).forEach((item, index) => {
        const order = item.querySelector(".item-order")
        if (!order) return
        order.textContent = inactive ? "" : String(index + 1)
      })
    })
  }

  valuesFor (key) {
    return listValues(this.listFor(key))
  }

  // Convenience for the common 2-column active/inactive layout.
  activeValues () {
    return this.valuesFor("active")
  }

  inactiveValues () {
    return this.valuesFor("inactive")
  }

  allColumnValues () {
    return this.listTargets.reduce((acc, list) => {
      const key = list.dataset.columnKey
      if (key) acc[key] = listValues(list)
      return acc
    }, {})
  }
}

export function listValues (list) {
  if (!list) return []
  return [...list.querySelectorAll(ITEM_SELECTOR)].map((item) => item.dataset.value).filter(Boolean)
}

export function itemAfter (list, y) {
  const items = [...list.querySelectorAll(`${ITEM_SELECTOR}:not(.is-dragging)`)]
  return items.find((item) => {
    const box = item.getBoundingClientRect()
    return y < box.top + box.height / 2
  }) || null
}

export function nextColumnKey (columns, currentKey) {
  if (!Array.isArray(columns) || !columns.length) return null
  const index = columns.findIndex((column) => column.key === currentKey)
  if (index < 0) return columns[0]?.key || null
  return columns[(index + 1) % columns.length].key
}
