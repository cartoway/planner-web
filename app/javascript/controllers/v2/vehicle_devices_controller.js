// Copyright © Cartoway
// Load device select options from /api/0.1/devices/:key/devices.json (replaces Paloma devicesObserveVehicle).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect () {
    const cfg = this.config()
    this.element.querySelectorAll("select[data-device]").forEach((select) => {
      this.loadDevice(select, cfg)
    })
  }

  config () {
    try {
      return JSON.parse(this.element.getAttribute("data-v2-js-config") || "{}")
    } catch (e) {
      return {}
    }
  }

  async loadDevice (select, cfg) {
    const key = select.dataset.device
    if (!key) return
    const customerId = cfg.customer_id
    if (!customerId) return
    const url = `/api/0.1/devices/${encodeURIComponent(key)}/devices.json?customer_id=${encodeURIComponent(customerId)}`
    try {
      const res = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      const data = await res.json()
      if (!res.ok || (data && data.error)) {
        this.flash((data && (data.error || data.message)) || res.statusText)
        return
      }
      this.fillOptions(select, Array.isArray(data) ? data : [])
      this.applyCurrentValue(select, cfg.devices || {}, key)
    } catch (e) {
      this.flash(e && e.message ? e.message : String(e))
    }
  }

  fillOptions (select, items) {
    const previous = select.multiple
      ? Array.from(select.selectedOptions).map((o) => o.value)
      : select.value
    select.innerHTML = ""
    if (!select.multiple) {
      const blank = document.createElement("option")
      blank.value = ""
      select.appendChild(blank)
    }
    items.forEach((item) => {
      const opt = document.createElement("option")
      const id = item.id != null ? item.id : item.value
      opt.value = id == null ? "" : String(id)
      opt.textContent = item.text != null ? String(item.text) : String(id)
      select.appendChild(opt)
    })
    if (select.multiple && previous.length) {
      Array.from(select.options).forEach((o) => { o.selected = previous.includes(o.value) })
    } else if (!select.multiple && previous) {
      select.value = previous
    }
  }

  applyCurrentValue (select, devices, key) {
    const current = devices[`${key}_id`] || devices[`${key}_ids`] || devices[`${key}_vehicle_id`] ||
      devices[`${key}_ref`] || devices[`${key}_user`]
    if (current == null || current === "") return
    if (select.multiple) {
      const values = Array.isArray(current) ? current.map(String) : [String(current)]
      Array.from(select.options).forEach((o) => { o.selected = values.includes(o.value) })
    } else {
      select.value = String(current)
    }
    select.dispatchEvent(new Event("change", { bubbles: true }))
  }

  flash (message) {
    if (!message) return
    let el = this.element.querySelector("[data-v2-vehicle-devices-error]")
    if (!el) {
      el = document.createElement("div")
      el.className = "alert alert-danger mt-2"
      el.setAttribute("role", "alert")
      el.dataset.v2VehicleDevicesError = "true"
      this.element.prepend(el)
    }
    el.textContent = message
  }
}
