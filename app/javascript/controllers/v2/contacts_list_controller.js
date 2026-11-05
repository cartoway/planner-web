// Copyright © Cartoway
// Shared contact rows: edit (unlock/lock), channel apply-all, drag-swap,
// already-sent include toggle (default: skip rows already notified).
import { Controller } from '@hotwired/stimulus'
import {
  channelForAlreadySentRow,
  effectiveAlreadySent
} from 'lib/contacts_already_sent'

export default class extends Controller {
  static targets = ['row', 'globalChannel', 'field', 'includeAlreadySent']
  static values = { allowReorder: { type: Boolean, default: false } }

  connect () {
    this.dragRow = null
    this.boundPointerDown = this.onPointerDown.bind(this)
    document.addEventListener('pointerdown', this.boundPointerDown, true)
    const form = this.element.closest('form')
    if (form) {
      this.boundSubmit = this.enableForSubmit.bind(this)
      form.addEventListener('submit', this.boundSubmit)
    }
    this.refreshGroupCounts()
  }

  disconnect () {
    document.removeEventListener('pointerdown', this.boundPointerDown, true)
    if (this.boundSubmit) {
      const form = this.element.closest('form')
      if (form) form.removeEventListener('submit', this.boundSubmit)
    }
  }

  applyGlobalChannel () {
    if (!this.hasGlobalChannelTarget) return
    const value = this.globalChannelTarget.value
    const includeAlreadySent = this.includeAlreadySentEnabled()
    this.rowTargets.forEach((row) => {
      if (row.hidden || row.classList.contains('d-none')) return
      if (this.rowAlreadySent(row) && !includeAlreadySent) return
      const select = row.querySelector('[data-contacts-channel]')
      if (select) select.value = value
    })
    this.refreshGroupCounts()
  }

  toggleIncludeAlreadySent () {
    const include = this.includeAlreadySentEnabled()
    this.rowTargets.forEach((row) => {
      if (!this.rowAlreadySent(row)) return
      this.setRowChannel(row, channelForAlreadySentRow({
        alreadySent: true,
        includeAlreadySent: include,
        defaultChannel: row.dataset.contactsDefaultChannel
      }))
    })
    this.refreshGroupCounts()
  }

  // Editing email/phone clears "already sent" for that row (contact no longer matches last transmit).
  markContactChanged (event) {
    const row = event.currentTarget.closest('[data-v2--contacts-list-target="row"]')
    if (!row || row.dataset.contactsSent !== 'true') return

    const email = row.querySelector('[data-contacts-field="email"]')?.value
    const phone = row.querySelector('[data-contacts-field="phone"]')?.value
    const alreadySent = effectiveAlreadySent({
      wasSent: true,
      originalEmail: row.dataset.contactsOriginalEmail,
      originalPhone: row.dataset.contactsOriginalPhone,
      email,
      phone
    })
    row.dataset.contactsAlreadySent = alreadySent ? 'true' : 'false'

    if (alreadySent) {
      this.setRowChannel(row, channelForAlreadySentRow({
        alreadySent: true,
        includeAlreadySent: this.includeAlreadySentEnabled(),
        defaultChannel: row.dataset.contactsDefaultChannel
      }))
    } else if (this.rowChannel(row) === 'none') {
      this.setRowChannel(row, row.dataset.contactsDefaultChannel || 'none')
    }
    this.refreshGroupCounts()
  }

  unlock (event) {
    event.preventDefault()
    const button = event.currentTarget
    const group = button.closest('.input-group')
    const input = group && group.querySelector('[data-contacts-lockable]')
    if (!input) return

    this.lockAllExcept(input)
    input.disabled = false
    button.classList.add('d-none')
    input.focus()
    input.select?.()
  }

  lockField (event) {
    this.lockInput(event.currentTarget)
  }

  // Disabled fields are omitted from submit — re-enable lockable fields in visible rows.
  enableForSubmit () {
    this.rowTargets.forEach((row) => {
      if (row.hidden || row.classList.contains('d-none')) return
      row.querySelectorAll('[data-contacts-lockable]').forEach((input) => {
        input.disabled = false
      })
    })
  }

  dragStart (event) {
    if (!this.allowReorderValue) return
    this.dragRow = event.currentTarget.closest('[data-v2--contacts-list-target="row"]')
    if (!this.dragRow) return
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/plain', this.dragRow.dataset.rowId || '')
    this.dragRow.classList.add('is-dragging')
  }

  dragOver (event) {
    if (!this.allowReorderValue || !this.dragRow) return
    event.preventDefault()
    event.dataTransfer.dropEffect = 'move'
  }

  drop (event) {
    if (!this.allowReorderValue || !this.dragRow) return
    event.preventDefault()
    const target = event.currentTarget.closest('[data-v2--contacts-list-target="row"]')
    if (target && target !== this.dragRow) this.swapContacts(this.dragRow, target)
    this.dragEnd()
  }

  dragEnd () {
    if (this.dragRow) this.dragRow.classList.remove('is-dragging')
    this.dragRow = null
  }

  // --- private ---

  includeAlreadySentEnabled () {
    return this.hasIncludeAlreadySentTarget && this.includeAlreadySentTarget.checked
  }

  rowAlreadySent (row) {
    return row.dataset.contactsAlreadySent === 'true'
  }

  rowChannel (row) {
    return row.querySelector('[data-contacts-channel]')?.value || 'none'
  }

  setRowChannel (row, channel) {
    const select = row.querySelector('[data-contacts-channel]')
    if (select) select.value = channel
  }

  onPointerDown (event) {
    const unlocked = this.element.querySelector('[data-contacts-lockable]:not([disabled])')
    if (!unlocked) return
    const group = unlocked.closest('.input-group')
    if (group && group.contains(event.target)) return
    this.lockInput(unlocked)
  }

  lockAllExcept (keep) {
    this.fieldTargets.forEach((input) => {
      if (input !== keep) this.lockInput(input)
    })
  }

  lockInput (input) {
    if (!input || input.disabled) return
    input.disabled = true
    const pencil = input.closest('.input-group')?.querySelector('[data-contacts-edit]')
    if (pencil) pencil.classList.remove('d-none')
    this.refreshGroupCounts()
  }

  refreshGroupCounts () {
    const channel = this.hasGlobalChannelTarget ? this.globalChannelTarget.value : 'email'
    const field = channel === 'sms' ? 'phone' : 'email'
    const toneClasses = ['text-bg-success', 'text-bg-warning', 'text-bg-danger']

    this.element.querySelectorAll('[data-contacts-group]').forEach((group) => {
      const badge = group.querySelector('[data-contacts-group-count]')
      if (!badge) return
      const rows = this.visibleRowsIn(group)
      this.applyCountBadge(badge, this.filledCount(rows, channel, field), rows.length, toneClasses)
    })

    const totalBadge = this.element.closest('.modal')?.querySelector('[data-contacts-total-count]')
    if (totalBadge) {
      const rows = this.visibleRowsIn(this.element)
      this.applyCountBadge(totalBadge, this.filledCount(rows, channel, field), rows.length, toneClasses)
    }
  }

  visibleRowsIn (root) {
    return [...root.querySelectorAll('[data-v2--contacts-list-target="row"]')]
      .filter((row) => !row.hidden && !row.classList.contains('d-none'))
  }

  filledCount (rows, channel, field) {
    if (channel === 'none') return 0
    return rows.reduce((count, row) => {
      const input = row.querySelector(`[data-contacts-field="${field}"]`)
      return count + (input?.value?.trim() ? 1 : 0)
    }, 0)
  }

  applyCountBadge (badge, filled, total, toneClasses) {
    badge.textContent = `${filled}/${total}`
    badge.classList.remove(...toneClasses)
    badge.classList.add(this.countBadgeClass(filled, total))
  }

  countBadgeClass (filled, total) {
    if (total === 0 || filled >= total) return 'text-bg-success'
    if (filled / total > 0.75) return 'text-bg-warning'
    return 'text-bg-danger'
  }

  swapContacts (rowA, rowB) {
    ;['email', 'phone'].forEach((field) => {
      const inputA = rowA.querySelector(`[data-contacts-field="${field}"]`)
      const inputB = rowB.querySelector(`[data-contacts-field="${field}"]`)
      if (!inputA || !inputB) return
      const tmp = inputA.value
      inputA.value = inputB.value
      inputB.value = tmp
      this.lockInput(inputA)
      this.lockInput(inputB)
    })
    ;[rowA, rowB].forEach((row) => {
      if (row.dataset.contactsSent !== 'true') return
      this.markContactChanged({ currentTarget: row.querySelector('[data-contacts-field="email"]') || row })
    })
    this.refreshGroupCounts()
  }
}
