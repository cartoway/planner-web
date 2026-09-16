// Copyright © Cartoway
// Download Cartoway Field reporting CSV (replaces Paloma/jQuery reporting.js on v2).
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["beginDate", "endDate", "withActions", "submit", "status"]
  static values = {
    url: String,
    customerId: Number,
    locale: String,
    noContent: String,
    success: String,
    fail: String,
    retry: String,
    downloading: String
  }

  async download (event) {
    event.preventDefault()
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.textContent = this.downloadingValue || this.submitTarget.textContent
    }
    const params = new URLSearchParams({
      customer_id: String(this.customerIdValue),
      begin_date: this.beginDateTarget.value,
      end_date: this.endDateTarget.value,
      with_actions: this.hasWithActionsTarget && this.withActionsTarget.checked ? "true" : "false",
      locale: this.localeValue || "en"
    })
    try {
      const response = await fetch(`${this.urlValue}?${params}`, {
        method: "GET",
        credentials: "same-origin",
        headers: { Accept: "text/csv" }
      })
      if (response.status === 204) {
        this._flash(this.noContentValue, false)
        return
      }
      if (!response.ok) {
        this._flash((await response.text()) || this.failValue, true)
        return
      }
      const blob = await response.blob()
      const url = window.URL.createObjectURL(blob)
      const a = document.createElement("a")
      a.href = url
      a.download = "reporting.csv"
      document.body.appendChild(a)
      a.click()
      a.remove()
      window.URL.revokeObjectURL(url)
      this._flash(this.successValue, false)
    } catch (e) {
      this._flash(this.failValue, true)
    } finally {
      if (this.hasSubmitTarget) {
        this.submitTarget.disabled = false
        this.submitTarget.textContent = this.retryValue || this.submitTarget.textContent
      }
    }
  }

  _flash (message, isError) {
    if (!this.hasStatusTarget) return
    this.statusTarget.textContent = message
    this.statusTarget.classList.remove("d-none", "alert-danger", "alert-info")
    this.statusTarget.classList.add(isError ? "alert-danger" : "alert-info")
  }
}
