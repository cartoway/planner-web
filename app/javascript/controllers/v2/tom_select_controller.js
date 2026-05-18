// Copyright © Cartoway
// Tom Select for multi-select + search (v2 sidebar; replaces Select2 on tag fields).
import { Controller } from "@hotwired/stimulus"
import TomSelect from "tom-select"

function escapeAttr (s) {
  if (s == null || s === "") return ""
  return String(s).replace(/&/g, "&amp;").replace(/"/g, "&quot;").replace(/</g, "&lt;")
}

export default class extends Controller {
  static values = {
    create: { type: Boolean, default: false },
    placeholder: { type: String, default: "" },
    createUrl: { type: String, default: "/api/0.1/tags.json" },
    /** When true: any `<select>` (single or multiple) — Lookbook demos; plain Tom Select without tag render/create. */
    simple: { type: Boolean, default: false }
  }

  /**
   * Prefer `data-controller` on the `<select>` (v2 destination/visit forms). Fallback: inner `select[multiple]`
   * inside a wrapper. Bulk modal uses the select as the host. Tag names must end with `[tag_ids][]` for Rails.
   */
  resolveTargetSelect () {
    if (this.simpleValue) {
      const host = this.element
      if (host.matches && host.matches("select")) return host
      return host.querySelector ? host.querySelector("select") : null
    }
    const host = this.element
    if (host.matches && host.matches("select")) {
      if (host.multiple) return host
      const n = host.getAttribute("name") || ""
      const id = host.getAttribute("id") || ""
      if (n.includes("tag_ids") || id === "from_visit_tags" || id === "to_visit_tags") {
        host.multiple = true
        return host
      }
      return null
    }
    let el = host.querySelector("select[multiple]")
    if (el) return el
    el = host.querySelector("select[name*='tag_ids'], select#from_visit_tags, select#to_visit_tags")
    if (el && el.tagName === "SELECT" && !el.multiple) el.multiple = true
    return el
  }

  connect () {
    const el = this.resolveTargetSelect()
    if (!el) return
    if (el.tomselect) {
      try {
        el.tomselect.destroy()
      } catch (e) { /* ignore */ }
    }
    this.selectElement = el

    const self = this
    const run = () => {
      this._tomSelectRaf = null
      if (!el.isConnected) return
      try {
        if (this.simpleValue) {
          this.initSimpleTomSelect(el)
        } else {
          this.initTagTomSelect(el, self)
        }
      } catch (err) {
        if (typeof console !== "undefined" && console.error) {
          console.error("[v2--tom-select] init failed", err)
        }
      }
    }
    this._tomSelectRaf = requestAnimationFrame(run)
  }

  /** Plain Tom Select for generic single/multi selects (e.g. Lookbook design system). */
  initSimpleTomSelect (el) {
    const plugins = ["dropdown_input"]
    if (el.multiple) plugins.push("remove_button")
    this.instance = new TomSelect(el, {
      plugins,
      // Must be the string 'body' so Tom Select runs positionDropdown() (strict ===); document.body skips it and the menu misaligns.
      dropdownParent: "body",
      persist: false,
      maxItems: el.multiple ? null : 1,
      hideSelected: !!el.multiple,
      placeholder: this.placeholderValue || "",
      create: false,
      closeAfterSelect: !el.multiple
    })
  }

  /** Tag lists with icons/colors + optional API create (v2 destination / visit forms). */
  initTagTomSelect (el, self) {
    // dropdownParent: body — sidebar flex stack uses overflow:hidden; default in-tree dropdown is clipped (~1 row).
    // dropdown_input — dedicated search field in the panel (multi-select tag lists).
    this.instance = new TomSelect(el, {
      plugins: ["remove_button", "dropdown_input"],
      // Must be the string 'body' so Tom Select runs positionDropdown() (strict ===); document.body skips it and the menu misaligns.
      dropdownParent: "body",
      persist: false,
      maxItems: null,
      hideSelected: true,
      placeholder: this.placeholderValue || "",
      create: this.createValue
        ? function (input, callback) {
            self.createTag(input, callback)
          }
        : false,
      render: {
        option: (data, escape) => self.renderTagOption(data, escape),
        item: (data, escape) => self.renderTagItem(data, escape)
      }
    })
  }

  disconnect () {
    if (this._tomSelectRaf != null) {
      cancelAnimationFrame(this._tomSelectRaf)
      this._tomSelectRaf = null
    }
    if (this.instance) {
      try {
        this.instance.destroy()
      } catch (e) { /* ignore */ }
      this.instance = null
    } else if (this.selectElement && this.selectElement.tomselect) {
      try {
        this.selectElement.tomselect.destroy()
      } catch (e) { /* ignore */ }
    }
    this.selectElement = null
  }

  renderTagOption (data, escape) {
    const opt = this.findOptionEl(data.value)
    return this.renderTagRow(opt, data.text, escape)
  }

  renderTagItem (data, escape) {
    const opt = this.findOptionEl(data.value)
    return this.renderTagRow(opt, data.text, escape)
  }

  findOptionEl (value) {
    const sel = this.selectElement || this.element
    if (!sel || value == null || value === "") return null
    const esc =
      typeof CSS !== "undefined" && typeof CSS.escape === "function"
        ? CSS.escape(String(value))
        : String(value).replace(/\\/g, "\\\\").replace(/"/g, '\\"')
    return sel.querySelector(`option[value="${esc}"]`)
  }

  renderTagRow (opt, text, escape) {
    const label = escape(text || "")
    const color = opt?.dataset?.color
    const icon = opt?.dataset?.icon
    if (icon && color) {
      return `<span><i class="fa ${escapeAttr(icon)}" style="color:#${escapeAttr(color)}"></i>&nbsp;</span><span>${label}</span>`
    }
    if (icon) {
      return `<span><i class="fa ${escapeAttr(icon)}"></i>&nbsp;</span><span>${label}</span>`
    }
    if (color) {
      return `<span><i class="fa fa-flag" style="color:#${escapeAttr(color)}"></i>&nbsp;</span><span>${label}</span>`
    }
    return `<span>${label}</span>`
  }

  async createTag (input, callback) {
    const term = (input || "").trim()
    if (!term) {
      callback()
      return
    }
    const token = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    try {
      const res = await fetch(this.createUrlValue, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          ...(token ? { "X-CSRF-Token": token } : {})
        },
        body: JSON.stringify({ label: term, ref: `#${term}` })
      })
      if (!res.ok) {
        callback()
        return
      }
      const data = await res.json()
      const id = data.id != null ? String(data.id) : null
      const label = data.label != null ? String(data.label) : term
      if (!id) {
        callback()
        return
      }
      const opt = new Option(label, id, true, true)
      const sel = this.selectElement || this.element
      sel.appendChild(opt)
      callback({ value: id, text: label })
    } catch (e) {
      callback()
    }
  }
}
