// Copyright © Cartoway
// Application pack - prepared for Importmaps + Hotwire (Rails 6+)

'use strict'

const MIN_CHARS = 3
const DEBOUNCE_MS = 300

// Parses "key:value" parts from input. Accepts any key:value for badge (server validates localized keys).
function parseKeyValueFilters (input) {
  if (!input || !input.includes(':')) return []
  const result = []
  input.split(/\s+/).forEach(part => {
    const colonIdx = part.indexOf(':')
    if (colonIdx > 0) {
      const key = part.slice(0, colonIdx).trim()
      const value = part.slice(colonIdx + 1).trim()
      if (key && value) {
        result.push({ key, value, raw: `${key}:${value}` })
      }
    }
  })
  return result
}

// Checks if input has enough chars for auto-search (3+ in value part or whole for plain text).
function hasMinCharsForSearch (input) {
  if (!input || input.length < MIN_CHARS) return false
  if (input.includes(':')) {
    const parts = input.split(':', 2)
    return (parts[1] || '').trim().length >= MIN_CHARS
  }
  return input.trim().length >= MIN_CHARS
}

function initDestinationsSearch () {
  const form = document.getElementById('destinations-search-form')
  const input = document.getElementById('search-query')
  if (!form || !input) return

  let debounceTimer = null

  function submitForm (additionalFilters = []) {
    if (additionalFilters.length) {
      additionalFilters.forEach(raw => {
        const field = document.createElement('input')
        field.type = 'hidden'
        field.name = 'filters[]'
        field.value = raw
        form.appendChild(field)
      })
      input.value = ''
    }
    form.submit()
  }

  input.addEventListener('input', function () {
    clearTimeout(debounceTimer)
    if (!hasMinCharsForSearch(this.value)) return
    debounceTimer = setTimeout(() => submitForm(), DEBOUNCE_MS)
  })

  input.addEventListener('keydown', function (e) {
    if (e.key !== 'Enter') return
    e.preventDefault()
    const val = this.value.trim()
    const filters = parseKeyValueFilters(val)
    if (filters.length) {
      submitForm(filters.map(f => f.raw))
    } else if (hasMinCharsForSearch(val)) {
      submitForm()
    }
  })
}

// Bootstrap for v2 layout - no jQuery dependency, works with Turbolinks
const initV2 = function () {
  if (document.body.dataset.controller && document.body.dataset.controller.includes('v2')) {
    window.dispatchEvent(new CustomEvent('application-v2:loaded'))
  }
  if (document.body.dataset.controller && document.body.dataset.controller.includes('destinations')) {
    initDestinationsSearch()
  }
}
if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initV2)
} else {
  initV2()
}
document.addEventListener('turbo:load', initV2)
document.addEventListener('turbo:frame-load', initV2)
document.addEventListener('turbolinks:load', initV2)

// Destinations index - multiple selection
const initDestinationsSelection = function () {
  const list = document.getElementById('destinations-list')
  if (!list || list.dataset.selectionInitialized === 'true') return

  const table = document.getElementById('destinations-table')
  if (!table) return

  list.dataset.selectionInitialized = 'true'
  const tbody = table.querySelector('tbody')
  const headerCheckbox = table.querySelector('.index_toggle_selection')
  const deleteBtn = document.getElementById('multiple-delete')
  const checkboxes = tbody ? tbody.querySelectorAll('.destination-checkbox') : []

  // Sync header checkbox state based on row checkboxes
  const updateHeaderCheckbox = function () {
    if (!headerCheckbox || !checkboxes.length) return
    const checked = Array.from(checkboxes).filter(cb => cb.checked)
    headerCheckbox.checked = checked.length === checkboxes.length
    headerCheckbox.indeterminate = checked.length > 0 && checked.length < checkboxes.length
  }

  // Toggle all row checkboxes
  if (headerCheckbox) {
    headerCheckbox.addEventListener('change', function () {
      checkboxes.forEach(cb => { cb.checked = headerCheckbox.checked })
      updateHeaderCheckbox()
    })
  }

  // Update header when row checkbox changes
  checkboxes.forEach(function (cb) {
    cb.addEventListener('change', updateHeaderCheckbox)
  })

  // Delete selected - uses API DELETE /api/0.1/destinations.json?ids=1,2,3
  if (deleteBtn) {
    deleteBtn.addEventListener('click', function () {
      const selectedIds = Array.from(checkboxes)
        .filter(cb => cb.checked)
        .map(cb => cb.value)
      if (selectedIds.length === 0) return

      const confirmMsg = (typeof I18n !== 'undefined' && I18n.t) ? I18n.t('all.verb.destroy_confirm') : 'Are you sure?'
      if (!confirm(confirmMsg)) return

      const url = '/api/0.1/destinations.json?ids=' + selectedIds.join(',')
      const meta = document.querySelector('meta[name="csrf-token"]')
      const token = meta ? meta.getAttribute('content') : null

      const req = new XMLHttpRequest()
      req.open('DELETE', url, true)
      req.setRequestHeader('X-Requested-With', 'XMLHttpRequest')
      if (token) req.setRequestHeader('X-CSRF-Token', token)
      req.setRequestHeader('Accept', 'application/json')

      req.onload = function () {
        if (req.status === 204 || req.status === 200) {
          window.Turbolinks && window.Turbolinks.visit(window.location.href, { action: 'replace' })
        } else {
          try {
            const err = JSON.parse(req.responseText)
            alert(err.message || err.error || 'Request failed')
          } catch (e) {
            alert('Request failed')
          }
        }
      }
      req.onerror = function () { alert('Request failed') }
      req.send()
    })
  }

  updateHeaderCheckbox()
}

document.addEventListener('DOMContentLoaded', initDestinationsSelection)
document.addEventListener('turbolinks:load', initDestinationsSelection)
