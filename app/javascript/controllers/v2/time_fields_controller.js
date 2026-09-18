// Copyright © Cartoway
// Schedule HH:MM / HH:MM:SS inputs via Maskito (replaces jQuery timeEntry on v2).
import { Controller } from "@hotwired/stimulus"
import { Maskito, maskitoUpdateElement } from "@maskito/core"
import { maskitoParseTime, maskitoStringifyTime, maskitoTime } from "@maskito/kit"
import { isScheduleTimeName, maskitoTimeParams } from "lib/schedule_time"

export default class extends Controller {
  static values = {
    invalidMessage: { type: String, default: "" }
  }

  connect () {
    this.masks = new WeakMap()
    this.onFocusIn = this.onFocusIn.bind(this)
    this.onBlur = this.onBlur.bind(this)
    this.onSubmit = this.onSubmit.bind(this)
    this.element.addEventListener("focusin", this.onFocusIn)
    this.element.addEventListener("focusout", this.onBlur)
    this.element.addEventListener("submit", this.onSubmit)
    this.element.querySelectorAll("input[type='text']").forEach((input) => this.ensureMask(input))
  }

  disconnect () {
    this.element.removeEventListener("focusin", this.onFocusIn)
    this.element.removeEventListener("focusout", this.onBlur)
    this.element.removeEventListener("submit", this.onSubmit)
    this.element.querySelectorAll("input[type='text']").forEach((input) => this.destroyMask(input))
  }

  onFocusIn (event) {
    this.ensureMask(event.target)
  }

  onBlur (event) {
    const input = event.target
    if (!this.isTimeInput(input)) return
    this.ensureMask(input)
    this.complete(input)
  }

  onSubmit () {
    this.element.querySelectorAll("input[type='text']").forEach((input) => {
      if (!this.isTimeInput(input)) return
      this.ensureMask(input)
      this.complete(input)
    })
  }

  ensureMask (input) {
    if (!this.isTimeInput(input) || this.masks.has(input)) return
    input.setAttribute("inputmode", "numeric")
    input.setAttribute("autocomplete", "off")
    const masked = new Maskito(input, maskitoTime(maskitoTimeParams(input.name)))
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
    if (raw === "") {
      input.setCustomValidity("")
      return
    }
    const params = maskitoTimeParams(input.name)
    const completed = maskitoStringifyTime(maskitoParseTime(raw, params), params)
    if (completed !== input.value) maskitoUpdateElement(input, completed)
    input.setCustomValidity("")
  }

  isTimeInput (el) {
    return el instanceof HTMLInputElement && el.type === "text" && isScheduleTimeName(el.name)
  }
}
