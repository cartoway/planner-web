// Copyright © Cartoway
// Port of customers_edit DOM toggles (v1 Paloma/customers.js) for the v2 sidebar form.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect () {
    this.syncAll()
  }

  syncAll () {
    this.syncExternalCallback()
    this.syncSoftUpperBound()
    this.syncVehiclePosition()
    this.syncProofRetention()
    this.syncNotificationWraps()
    this.syncSuiviSection()
    this.syncOperationsMobile()
  }

  syncExternalCallback () {
    this.toggleByCheckbox("#customer_enable_external_callback", "#external_callback_container")
  }

  syncSoftUpperBound () {
    this.toggleByCheckbox("#customer_enable_optimization_soft_upper_bound", "#optimization_soft_upper_bound")
  }

  syncVehiclePosition () {
    const positionOn = this.checked("#customer_enable_vehicle_position")
    const traceOn = this.checked("#customer_vehicle_position_keep_trace")
    this.toggleEl("#vehicle_position_trace_options", !positionOn)
    this.toggleEl("#vehicle_position_retention_days_wrap", !(positionOn && traceOn))
  }

  syncProofRetention () {
    this.toggleByCheckbox("#customer_enable_proofs", "#proof_retention_days_wrap")
  }

  syncNotificationWraps () {
    this.toggleByCheckbox("#customer_enable_sms_driver", "#customer_sms_driver_template_wrap")
    this.toggleByCheckbox("#customer_enable_email_destination", "#customer_destination_email_template_wrap")
    this.toggleByCheckbox("#customer_enable_sms_destination", "#customer_sms_template_wrap")
    this.toggleByCheckbox("#customer_enable_sms_intransit", "#customer_sms_intransit_template_wrap")
  }

  syncSuiviSection () {
    const section = this.element.querySelector("#customer_suivi_section")
    if (!section) return
    const keys = String(section.dataset.operationsDevices || "").split(",").filter(Boolean)
    const enabled = keys.some((key) => this.checked(`#customer_devices_${key}_enable`))
    section.classList.toggle("d-none", !enabled)
  }

  // Deliver v2 (operations_mobile) only usable when Cartoway Deliver is enabled.
  syncOperationsMobile () {
    const checkbox = this.checkbox("#customer_operations_mobile")
    if (!checkbox) return
    const deliverOn = this.checked("#customer_devices_deliver_enable")
    checkbox.disabled = !deliverOn
    if (!deliverOn) checkbox.checked = false
  }

  toggleByCheckbox (checkboxSelector, targetSelector) {
    const checkbox = this.checkbox(checkboxSelector)
    if (!checkbox) return
    this.toggleEl(targetSelector, !checkbox.checked)
  }

  toggleEl (selector, hide) {
    const el = this.element.querySelector(selector)
    if (!el) return
    el.classList.toggle("d-none", hide)
  }

  // Prefer the real checkbox — hidden_field_tag can steal the same id when id: nil is omitted.
  checkbox (selector) {
    return this.element.querySelector(`input[type="checkbox"]${selector}`) ||
      this.element.querySelector(selector)
  }

  checked (selector) {
    return !!this.checkbox(selector)?.checked
  }
}
