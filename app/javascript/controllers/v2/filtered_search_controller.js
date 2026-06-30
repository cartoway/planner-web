// Copyright © Cartoway
// Reusable filtered-search dropdown: open on focus/click, filter keys, insert `key:` tokens.

import { Controller } from '@hotwired/stimulus'

export default class extends Controller {
  static targets = ['input', 'dropdown', 'item', 'token']

  connect () {
    this._draftKey = ''
    this._onDocumentClick = this._onDocumentClick.bind(this)
    this._onClearDraft = () => this.clearDraftKey()
    document.addEventListener('click', this._onDocumentClick)
    this.element.addEventListener('filtered-search:clear-draft', this._onClearDraft)
    this._renderToken()
  }

  disconnect () {
    document.removeEventListener('click', this._onDocumentClick)
    this.element.removeEventListener('filtered-search:clear-draft', this._onClearDraft)
  }

  open () {
    if (!this.hasDropdownTarget) return
    this.dropdownTarget.classList.remove('d-none')
    if (this.hasInputTarget) this.inputTarget.setAttribute('aria-expanded', 'true')
    this.filter()
  }

  focusInput () {
    if (!this.hasInputTarget) return
    this.inputTarget.focus()
    this.open()
  }

  close () {
    if (!this.hasDropdownTarget) return
    this.dropdownTarget.classList.add('d-none')
    if (this.hasInputTarget) this.inputTarget.setAttribute('aria-expanded', 'false')
  }

  handleKeydown (event) {
    if (event.key === 'Escape') this.close()
    if (event.key === 'Backspace' && this._draftKey && !this.inputTarget.value) {
      event.preventDefault()
      this.clearDraftKey()
      this.open()
    }
  }

  filter () {
    if (!this.hasInputTarget) return
    const value = this.inputTarget.value || ''
    if (!this._draftKey && value.includes(':')) {
      const [candidateKey, ...rest] = value.split(':')
      const resolved = this._findMatchingKey(candidateKey)
      if (resolved) {
        this.setDraftKey(resolved)
        this.inputTarget.value = rest.join(':').replace(/^\s+/, '')
      }
    }
    if (this._draftKey) return
    const typedKey = value.includes(':') ? value.split(':', 1)[0].trim().toLowerCase() : value.trim().toLowerCase()
    this.itemTargets.forEach((item) => {
      const key = (item.dataset.searchKey || '').toLowerCase()
      const visible = !typedKey || key.includes(typedKey)
      item.classList.toggle('d-none', !visible)
    })
  }

  keepFocus (event) {
    event.preventDefault()
  }

  pick (event) {
    const btn = event.currentTarget
    const key = btn?.dataset?.searchKey
    if (!key || !this.hasInputTarget) return
    this.setDraftKey(key)
    this.inputTarget.value = ''
    this.inputTarget.focus()
    if (typeof this.inputTarget.setSelectionRange === 'function') {
      this.inputTarget.setSelectionRange(0, 0)
    }
    this.open()
  }

  setDraftKey (key) {
    this._draftKey = key || ''
    if (this.hasInputTarget) this.inputTarget.dataset.filterKeyDraft = this._draftKey
    this._renderToken()
  }

  clearDraftKey () {
    this.setDraftKey('')
  }

  _renderToken () {
    if (!this.hasTokenTarget) return
    const visible = !!this._draftKey
    this.tokenTarget.classList.toggle('d-none', !visible)
    this.tokenTarget.textContent = visible ? this._draftKey : ''
  }

  _findMatchingKey (candidate) {
    const normalized = (candidate || '').trim().toLowerCase()
    if (!normalized) return null
    const match = this.itemTargets.find((item) => (item.dataset.searchKey || '').toLowerCase() === normalized)
    return match ? match.dataset.searchKey : null
  }

  _onDocumentClick (event) {
    if (this.element.contains(event.target)) return
    this.close()
  }
}
