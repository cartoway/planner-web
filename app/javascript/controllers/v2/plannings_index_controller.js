// Copyright © Cartoway
// Planning list exports; column picker uses shared v2--transfer-list.
import { Controller } from "@hotwired/stimulus"
import { planningCompareUrl } from "lib/planning_compare_url"

export default class extends Controller {
  static targets = [
    "modal",
    "summary",
    "stopsGroup",
    "stop",
    "detailColumnsTemplate",
    "summaryColumnsTemplate",
    "routeId"
  ]

  static values = {
    noneSelected: String,
    compareNeedSelection: String,
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

  compare (event) {
    event.preventDefault()
    const ids = this.selectedIds()
    if (ids.length < 2) {
      this.flash(this.compareNeedSelectionValue || this.noneSelectedValue, "warning")
      return
    }
    window.location.href = planningCompareUrl(ids)
  }

  downloadSpreadsheet (event) {
    event.preventDefault()
    const ids = this.selectedIds()
    if (!ids.length) {
      this.flash(this.noneSelectedValue, "warning")
      return
    }
    const summary = this.hasSummaryTarget && this.summaryTarget.value === "true"
    const columns = this.spreadsheetValues("active")
    const skips = this.spreadsheetValues("inactive")
    const fallback = columns.length ? columns : columns.concat(skips)
    this.persistColumnsTemplate(summary)
    // POST body: Puma rejects QUERY_STRING > 10KB. Switch to HTTP QUERY when Rails supports it.
    planningExportDownload({
      format: "excel",
      ids,
      columns: (columns.length ? columns : fallback).join("|"),
      skips: columns.length ? skips.join("|") : "",
      stops: this.selectedStops().join("|"),
      summary,
      routeId: this.hasRouteIdTarget ? this.routeIdTarget.value : ""
    })
    this.hideModal()
  }

  spreadsheetValues (zone) {
    const transfer = this.transferList()
    if (transfer) return transfer.valuesFor(zone)
    const list = this.element.querySelector(`#spreadsheet-columns-container [data-column-key="${zone}"].item-list`)
    return list ? [...list.children].filter((item) => item.classList.contains("transfer-list-item")).map((item) => item.dataset.value).filter(Boolean) : []
  }

  persistColumnsTemplate (summary) {
    const template = summary && this.hasSummaryColumnsTemplateTarget
      ? this.summaryColumnsTemplateTarget
      : this.detailColumnsTemplateTarget
    this.transferList()?.serializeToTemplate(template)
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

// POST form download — prefer HTTP QUERY (RFC 10008) once Rails has via: :query.
export function planningExportDownload ({ format, ids, columns, skips, stops, summary, routeId }) {
  const fields = {
    stops: summary ? "" : (stops || ""),
    columns: columns || "",
    ids: ids.join(","),
    skips: skips || ""
  }
  if (summary) fields.summary = "true"
  const base = routeId ? `/routes/${routeId}/export` : "/plannings/export"
  postFormDownload(`${base}.${format}`, fields)
}

function postFormDownload (action, fields) {
  const form = document.createElement("form")
  form.method = "post"
  form.action = action
  form.style.display = "none"
  const token = document.querySelector('meta[name="csrf-token"]')?.content
  if (token) {
    const csrf = document.createElement("input")
    csrf.type = "hidden"
    csrf.name = "authenticity_token"
    csrf.value = token
    form.appendChild(csrf)
  }
  Object.entries(fields).forEach(([name, value]) => {
    if (value === undefined || value === null) return
    const input = document.createElement("input")
    input.type = "hidden"
    input.name = name
    input.value = value
    form.appendChild(input)
  })
  document.body.appendChild(form)
  form.submit()
  form.remove()
}

export { planningCompareUrl }
