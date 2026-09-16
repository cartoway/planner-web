// Copyright © Cartoway
// Clone or remove nested store-reload fieldsets on the v2 store form.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["list", "template"]

  add (event) {
    event.preventDefault()
    if (!this.hasListTarget || !this.hasTemplateTarget) return
    const all = Array.from(this.listTarget.querySelectorAll("fieldset"))
    const n = this.nextIndex(all)
    const html = this.templateTarget.innerHTML
      .replace(/store_reloads_attributes_0/g, `store_reloads_attributes_${n}`)
      .replace(/store\[store_reloads_attributes\]\[0\]/g, `store[store_reloads_attributes][${n}]`)
      .replace(/collapseStoreReload0/g, `collapseStoreReload${n}`)
    this.listTarget.insertAdjacentHTML("beforeend", html)
    const last = this.listTarget.querySelector("fieldset:last-of-type")
    const label = last?.querySelector(".store-reload-legend")
    if (label) {
      label.textContent = label.textContent.replace(String(label.dataset.index), String(n))
      label.dataset.index = n
    }
    last?.querySelector(".collapse")?.classList.add("show")
    last?.querySelector(".accordion-toggle")?.classList.remove("collapsed")
    last?.querySelector(".accordion-toggle")?.setAttribute("aria-expanded", "true")
    this.markDirty()
  }

  remove (event) {
    event.preventDefault()
    event.stopPropagation()
    const fieldset = event.currentTarget.closest("fieldset")
    if (!fieldset) return
    const flag = fieldset.querySelector(".store-reload-destroy-flag") || fieldset.querySelector('input[name*="[_destroy]"]')
    if (flag) {
      if (flag.type === "checkbox") flag.checked = true
      else flag.value = "1"
    }
    const idInput = fieldset.querySelector('input[name$="[id]"]')
    if (idInput && idInput.value) fieldset.classList.add("d-none")
    else fieldset.remove()
    this.markDirty()
  }

  markDirty () {
    this.element.closest("form")?.dispatchEvent(new Event("input", { bubbles: true }))
  }

  nextIndex (fieldsets) {
    let max = 0
    fieldsets.forEach((el) => {
      const name = el.querySelector('[name*="[store_reloads_attributes]"]')?.name
      const match = name?.match(/\[store_reloads_attributes\]\[(\d+)\]/)
      if (match) max = Math.max(max, Number(match[1]))
    })
    return max + 1
  }
}
