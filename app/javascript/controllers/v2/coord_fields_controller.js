// Copyright © Cartoway
// Lat/lng inputs via Maskito number mask (v2 destination / store forms).
import { Controller } from "@hotwired/stimulus"
import { Maskito, maskitoUpdateElement } from "@maskito/core"
import { maskitoNumber, maskitoParseNumber, maskitoStringifyNumber } from "@maskito/kit"
import { isCoordFieldName, maskitoCoordParams } from "lib/schedule_coord"

export default class extends Controller {
  connect () {
    this.masks = new WeakMap()
    this.onFocusIn = this.onFocusIn.bind(this)
    this.onBlur = this.onBlur.bind(this)
    this.onSubmit = this.onSubmit.bind(this)
    this.element.addEventListener("focusin", this.onFocusIn)
    this.element.addEventListener("focusout", this.onBlur)
    this.element.addEventListener("submit", this.onSubmit)
    this.element.querySelectorAll("input").forEach((input) => this.ensureMask(input))
  }

  disconnect () {
    this.element.removeEventListener("focusin", this.onFocusIn)
    this.element.removeEventListener("focusout", this.onBlur)
    this.element.removeEventListener("submit", this.onSubmit)
    this.element.querySelectorAll("input").forEach((input) => this.destroyMask(input))
  }

  onFocusIn (event) {
    this.ensureMask(event.target)
  }

  onBlur (event) {
    const input = event.target
    if (!this.isCoordInput(input)) return
    this.ensureMask(input)
    this.complete(input)
  }

  onSubmit () {
    this.element.querySelectorAll("input").forEach((input) => {
      if (!this.isCoordInput(input)) return
      this.ensureMask(input)
      this.complete(input)
    })
  }

  ensureMask (input) {
    if (!this.isCoordInput(input) || this.masks.has(input)) return
    if (input.type === "number") input.type = "text"
    input.setAttribute("inputmode", "decimal")
    input.setAttribute("autocomplete", "off")
    const masked = new Maskito(input, maskitoNumber(maskitoCoordParams(input.name)))
    this.masks.set(input, masked)
  }

  destroyMask (input) {
    const masked = this.masks.get(input)
    if (!masked) return
    masked.destroy()
    this.masks.delete(input)
  }

  complete (input) {
    const raw = input.value.trim()
    if (raw === "" || raw === "-") {
      if (raw === "-") maskitoUpdateElement(input, "")
      input.setCustomValidity("")
      return
    }
    const params = maskitoCoordParams(input.name)
    const num = maskitoParseNumber(raw, params)
    if (!Number.isFinite(num)) {
      input.setCustomValidity(this.invalidMessageValue || "Invalid coordinate")
      return
    }
    const completed = maskitoStringifyNumber(num, params)
    if (completed !== input.value) maskitoUpdateElement(input, completed)
    input.setCustomValidity("")
  }

  isCoordInput (el) {
    return el instanceof HTMLInputElement && isCoordFieldName(el.name)
  }
}
