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
    event.dataTransfer.setData("text/plain", event.currentTarget.dataset.value || "column")
    event.currentTarget.classList.add("is-dragging")
  }

  dragEnd (event) {
    event.currentTarget.classList.remove("is-dragging")
    this.dragItem = null
  }

  // Keep the node in place until drop: moving it on dragover makes the browser
  // cancel the drag and remove the chip (flex-wrap lists are especially brittle).
  allowDrop (event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  dragOver (event) {
    this.allowDrop(event)
  }

  drop (event) {
    event.preventDefault()
    event.stopPropagation()
    if (!this.dragItem) return
    const list = event.currentTarget
    placeItem(list, this.dragItem, event.clientX, event.clientY)
    this.applyListState(this.dragItem, list)
    this.refreshOrders()
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

  // Snapshot current lists into the <template> so the next open keeps this order
  // (the download also persists it server-side via columns/skips query params).
  serializeToTemplate (template) {
    if (!template?.content) return
    template.content.replaceChildren(
      ...this.listTargets.flatMap((list) => [...list.querySelectorAll(ITEM_SELECTOR)].map((item) => item.cloneNode(true)))
    )
  }
}

export function listValues (list) {
  if (!list) return []
  const items = list.children
    ? [...list.children].filter((item) => item.matches?.(ITEM_SELECTOR) || String(item.className || "").includes("transfer-list-item"))
    : [...list.querySelectorAll(ITEM_SELECTOR)]
  return items.map((item) => item.dataset.value).filter(Boolean)
}

export function placeItem (list, item, x, y) {
  const after = itemAfter(list, x, y)
  if (after == null) list.appendChild(item)
  else list.insertBefore(item, after)
}

export function itemAfter (list, x, y) {
  const items = [...list.querySelectorAll(`${ITEM_SELECTOR}:not(.is-dragging)`)]
  return items.find((item) => {
    const box = item.getBoundingClientRect()
    if (y < box.top) return true
    return y < box.bottom && x < box.left + box.width / 2
  }) || null
}

export function nextColumnKey (columns, currentKey) {
  if (!Array.isArray(columns) || !columns.length) return null
  const index = columns.findIndex((column) => column.key === currentKey)
  if (index < 0) return columns[0]?.key || null
  return columns[(index + 1) % columns.length].key
}
