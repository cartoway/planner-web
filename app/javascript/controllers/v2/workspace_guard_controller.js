// Copyright © Cartoway
// Multi-tab workspace guard: one fetch interceptor (same-origin) + BroadcastChannel.
import { Controller } from "@hotwired/stimulus"

export const CHANNEL = "cartoway-workspace"
export const HEADER = "X-Cartoway-Workspace"
export const CHANGED_HEADER = "X-Cartoway-Workspace-Changed"
export const STORAGE_KEY = "cartoway-workspace-user"

export function isMutatingMethod (method) {
  const m = (method || "GET").toUpperCase()
  return m !== "GET" && m !== "HEAD"
}

export function isSameOrigin (url, origin = window.location.origin) {
  try {
    return new URL(url, origin).origin === origin
  } catch {
    return false
  }
}

export function requestUrl (input) {
  if (typeof input === "string") return input
  if (input && typeof input.url === "string") return input.url
  return ""
}

export function isWorkspaceChangedResponse (response) {
  return response?.headers?.get?.(CHANGED_HEADER) === "1"
}

export default class extends Controller {
  static values = {
    userId: Number,
    changedMessage: { type: String, default: "" }
  }

  connect () {
    this.channel = typeof BroadcastChannel !== "undefined" ? new BroadcastChannel(CHANNEL) : null
    if (this.channel) {
      this.channel.onmessage = (event) => {
        if (String(event.data?.userId) === String(this.userIdValue)) return
        this.warnAndReload()
      }
    }

    const prev = typeof sessionStorage !== "undefined" ? sessionStorage.getItem(STORAGE_KEY) : null
    if (typeof sessionStorage !== "undefined") {
      sessionStorage.setItem(STORAGE_KEY, String(this.userIdValue))
    }
    if (prev && prev !== String(this.userIdValue)) {
      this.channel?.postMessage({ userId: this.userIdValue })
    }

    // Single injection point: fetch covers Turbo Drive and modern XHR replacements.
    this.originalFetch = window.fetch.bind(window)
    window.fetch = this.decorateFetch.bind(this)
    document.addEventListener("submit", this.boundSubmit = this.onSubmit.bind(this), true)
  }

  disconnect () {
    if (this.channel) this.channel.close()
    if (this.originalFetch) window.fetch = this.originalFetch
    document.removeEventListener("submit", this.boundSubmit, true)
  }

  decorateFetch (input, init = {}) {
    const url = requestUrl(input)
    const method = (init.method || (typeof input === "object" && input.method) || "GET").toUpperCase()
    if (isMutatingMethod(method) && isSameOrigin(url)) {
      const headers = new Headers(init.headers || (typeof input === "object" && input.headers) || {})
      if (!headers.has(HEADER)) headers.set(HEADER, String(this.userIdValue))
      init = { ...init, headers }
    }
    return this.originalFetch(input, init).then((response) => {
      if (isWorkspaceChangedResponse(response)) this.warnAndReload()
      return response
    })
  }

  onSubmit (event) {
    const form = event.target
    if (!(form instanceof HTMLFormElement)) return
    if (!isMutatingMethod(form.method || "get")) return

    const action = form.getAttribute("action") || window.location.href
    if (!isSameOrigin(action)) return

    let input = form.querySelector('input[name="cartoway_workspace"]')
    if (!input) {
      input = document.createElement("input")
      input.type = "hidden"
      input.name = "cartoway_workspace"
      form.appendChild(input)
    }
    input.value = String(this.userIdValue)
  }

  warnAndReload () {
    const message = this.changedMessageValue || "Workspace changed"
    window.alert(message)
    window.location.reload()
  }
}
