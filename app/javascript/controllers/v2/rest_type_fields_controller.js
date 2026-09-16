// Copyright © Cartoway
// Toggle window vs regulatory rest fields on v2 fleet forms (Paloma jQuery is not on the v2 layout).
import { Controller } from "@hotwired/stimulus"

function parseTimeToSeconds (value) {
  if (!value) return null
  const parts = String(value).split(":").map((part) => Number(part))
  if (parts.some((part) => Number.isNaN(part))) return null
  return (parts[0] || 0) * 3600 + (parts[1] || 0) * 60 + (parts[2] || 0)
}

function inheritedSeconds (el) {
  if (!el) return 0
  const seconds = Number(el.getAttribute("data-inherited-seconds"))
  return seconds > 0 ? seconds : 0
}

export default class extends Controller {
  static values = {
    prefix: { type: String, default: "vehicle_usage_set" },
    durationMustBeFilled: { type: String, default: "" },
    lapseMustBeFilled: { type: String, default: "" },
    durationMustBeSmaller: { type: String, default: "" }
  }

  connect () {
    this.apply(this.currentMode(), false)
  }

  change (event) {
    const el = event.target
    if (!el || el.name !== `${this.prefixValue}[rest_mode]`) return
    this.apply(el.value, true)
  }

  submit (event) {
    if (this.currentMode() !== "regulatory") return
    this.apply("regulatory", false)
    const durationEl = this.byId("rest_duration")
    const lapseEl = this.byId("rest_lapse")
    const duration = parseTimeToSeconds(durationEl && durationEl.value) || inheritedSeconds(durationEl)
    const lapse = parseTimeToSeconds(lapseEl && lapseEl.value) || inheritedSeconds(lapseEl)
    let msg = null
    if (!duration) msg = this.durationMustBeFilledValue
    else if (!lapse) msg = this.lapseMustBeFilledValue
    else if (duration >= lapse) msg = this.durationMustBeSmallerValue
    if (!msg) return
    event.preventDefault()
    this.showError(msg)
  }

  currentMode () {
    const name = `${this.prefixValue}[rest_mode]`
    const checked = this.element.querySelector(`input[name="${name}"]:checked`)
    if (checked) return checked.value
    const hidden = this.element.querySelector(`input[type="hidden"][name="${name}"]`)
    return (hidden && hidden.value) || "window"
  }

  apply (mode, userChanged) {
    const regulatory = mode === "regulatory"
    this.toggle(this.byId("rest_start_stop_input"), !regulatory)
    this.toggle(this.byId("rest_lapse_input"), regulatory)
    this.element.querySelectorAll(".rest-store-select").forEach((el) => this.toggle(el, !regulatory))
    this.element.querySelectorAll(".rest-duration-label-window").forEach((el) => this.toggle(el, !regulatory))
    this.element.querySelectorAll(".rest-duration-label-regulatory").forEach((el) => this.toggle(el, regulatory))
    this.element.querySelectorAll(".rest-duration-help-window").forEach((el) => this.toggle(el, !regulatory))

    if (regulatory) {
      this.clearValue(this.byId("rest_start"))
      this.clearValue(this.byId("rest_stop"))
      this.clearValue(this.byId("rest_start_day"))
      this.clearValue(this.byId("rest_stop_day"))
      this.clearValue(this.byId("store_rest_id"))
      if (userChanged) {
        this.clearValue(this.byId("rest_duration"))
        this.clearValue(this.byId("rest_lapse"))
      }
    } else {
      this.clearValue(this.byId("rest_lapse"))
    }
  }

  byId (suffix) {
    return this.element.querySelector(`#${this.prefixValue}_${suffix}`)
  }

  toggle (el, show) {
    if (!el) return
    el.style.display = show ? "" : "none"
  }

  clearValue (el) {
    if (el) el.value = ""
  }

  showError (msg) {
    let el = this.element.querySelector("[data-rest-type-error]")
    if (!el) {
      el = document.createElement("div")
      el.className = "alert alert-danger mt-2"
      el.setAttribute("data-rest-type-error", "")
      el.setAttribute("role", "alert")
      const host = this.byId("rest_type_input") || this.element
      host.appendChild(el)
    }
    el.textContent = msg
  }
}
