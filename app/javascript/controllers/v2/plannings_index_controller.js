// Copyright © Cartoway
// Planning list exports; column picker uses shared v2--transfer-list.
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "modal",
    "summary",
    "stopsGroup",
    "stop",
    "format",
    "detailColumnsTemplate",
    "summaryColumnsTemplate",
    "routeId"
  ]

  static values = {
    noneSelected: String,
    emailSuccess: String,
    emailFail: String,
    callbackUrl: String,
    apiKey: String,
    callbackSuccess: String,
    callbackFail: String
  }

  transferList () {
    const el = this.element.querySelector('[data-controller~="v2--transfer-list"]')
    return el && this.application.getControllerForElementAndIdentifier(el, "v2--transfer-list")
  }

  spreadsheet (event) {
    const ids = this.requireIds(event)
    if (!ids) return
    event.preventDefault()
    this.openSpreadsheetModal(event.currentTarget.dataset.summary === "true")
  }

  downloadSpreadsheet (event) {
    event.preventDefault()
    const ids = this.selectedIds()
    if (!ids.length) {
      this.flash(this.noneSelectedValue, "warning")
      return
    }
    const summary = this.hasSummaryTarget && this.summaryTarget.value === "true"
    const transfer = this.transferList()
    const columns = transfer ? transfer.activeValues() : []
    const skips = transfer ? transfer.inactiveValues() : []
    const fallback = columns.length ? columns : columns.concat(skips)
    window.location.href = planningExportUrl({
      format: this.selectedFormat(),
      ids,
      columns: (columns.length ? columns : fallback).join("|"),
      skips: columns.length ? skips.join("|") : "",
      stops: this.selectedStops().join("|"),
      summary,
      routeId: this.hasRouteIdTarget ? this.routeIdTarget.value : ""
    })
    this.hideModal()
  }

  openSpreadsheetModal (summary) {
    if (this.hasSummaryTarget) this.summaryTarget.value = summary ? "true" : "false"
    if (this.hasStopsGroupTarget) this.stopsGroupTarget.classList.toggle("d-none", !!summary)
    const template = summary && this.hasSummaryColumnsTemplateTarget
      ? this.summaryColumnsTemplateTarget
      : this.detailColumnsTemplateTarget
    this.transferList()?.loadFromTemplate(template)
    this.showModal()
  }

  selectedStops () {
    return this.stopTargets.filter((input) => input.checked).map((input) => input.value)
  }

  selectedFormat () {
    const checked = this.formatTargets.find((input) => input.checked)
    return checked ? checked.value : "excel"
  }

  showModal () {
    if (!this.hasModalTarget) return
    const Modal = window.bootstrap?.Modal
    if (Modal) Modal.getOrCreateInstance(this.modalTarget).show()
  }

  hideModal () {
    if (!this.hasModalTarget) return
    const Modal = window.bootstrap?.Modal
    if (Modal) Modal.getOrCreateInstance(this.modalTarget).hide()
  }

  ical (event) {
    const ids = this.requireIds(event)
    if (!ids) return
    const link = event.currentTarget
    const base = link.dataset.baseHref || link.href
    link.dataset.baseHref = base
    const url = new URL(base, window.location.origin)
    url.searchParams.set("ids", ids.join(","))
    link.href = url.toString()
  }

  async email (event) {
    event.preventDefault()
    const ids = this.requireIds(event)
    if (!ids) return
    const url = new URL(event.currentTarget.href, window.location.origin)
    url.searchParams.set("email", "true")
    url.searchParams.set("ids", ids.join(","))
    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, credentials: "same-origin" })
      this.flash(response.ok ? this.emailSuccessValue : this.emailFailValue, response.ok ? "success" : "danger")
    } catch (_error) {
      this.flash(this.emailFailValue, "danger")
    }
  }

  async callback (event) {
    event.preventDefault()
    if (this.callbackPending) return
    this.callbackPending = true
    const token = document.querySelector('meta[name="csrf-token"]')?.content
    const body = new URLSearchParams({
      api_key: this.apiKeyValue,
      planning_ids: this.selectedIds().join(",")
    })
    try {
      const response = await fetch(this.callbackUrlValue, {
        method: "POST",
        headers: {
          "X-CSRF-Token": token,
          Accept: "application/json",
          "Content-Type": "application/x-www-form-urlencoded"
        },
        body,
        credentials: "same-origin"
      })
      this.flash(response.ok ? this.callbackSuccessValue : this.callbackFailValue, response.ok ? "success" : "danger")
    } catch (_error) {
      this.flash(this.callbackFailValue, "danger")
    } finally {
      this.callbackPending = false
    }
  }

  selectedIds () {
    return [...this.element.querySelectorAll("#plannings tbody input[type=checkbox]:checked")]
      .filter((box) => !box.disabled)
      .map((box) => box.value)
      .filter(Boolean)
  }

  requireIds (event) {
    const ids = this.selectedIds()
    if (ids.length) return ids
    event.preventDefault()
    this.flash(this.noneSelectedValue, "warning")
    return null
  }

  flash (message, kind) {
    const el = document.createElement("div")
    el.className = `alert alert-${kind} mx-3 mt-3 mb-0`
    el.setAttribute("role", "alert")
    el.textContent = message
    this.element.prepend(el)
  }
}

export function planningExportUrl ({ format, ids, columns, skips, stops, summary, routeId }) {
  const params = new URLSearchParams({
    stops: summary ? "" : (stops || ""),
    columns: columns || "",
    ids: ids.join(","),
    skips: skips || ""
  })
  if (summary) params.set("summary", "true")
  const base = routeId ? `/routes/${routeId}` : "/plannings"
  return `${base}.${format}?${params.toString()}`
}
