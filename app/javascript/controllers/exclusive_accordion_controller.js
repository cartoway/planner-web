// Copyright © Cartoway
// Stimulus wrapper around ExclusiveAccordion (details or collapse panels).
import { Controller } from '@hotwired/stimulus'
import { ExclusiveAccordion } from 'lib/exclusive_accordion'

export default class extends Controller {
  static values = {
    itemSelector: String,
    panelSelector: String,
    headingSelector: String,
    scrollParentSelector: String,
    stickyTopSelector: String,
    mode: { type: String, default: 'details' },
    openClass: { type: String, default: 'in' }
  }

  connect () {
    let scrollParent = window
    if (this.hasScrollParentSelectorValue) {
      scrollParent = this.element.matches(this.scrollParentSelectorValue)
        ? this.element
        : (this.element.closest(this.scrollParentSelectorValue) ||
          document.querySelector(this.scrollParentSelectorValue) ||
          this.element)
    }
    this.accordion = new ExclusiveAccordion({
      root: this.element,
      itemSelector: this.itemSelectorValue,
      panelSelector: this.panelSelectorValue,
      headingSelector: this.headingSelectorValue,
      scrollParent,
      stickyTopSelector: this.hasStickyTopSelectorValue ? this.stickyTopSelectorValue : null,
      mode: this.modeValue,
      openClass: this.openClassValue,
      onOpen: (item) => {
        item.dispatchEvent(new CustomEvent('exclusive-accordion:open', { bubbles: true }))
      },
      onCloseAll: () => {
        this.element.dispatchEvent(new CustomEvent('exclusive-accordion:close-all', { bubbles: true }))
      }
    })
    this._onClick = (event) => { this.accordion.handleClick(event) }
    this.element.addEventListener('click', this._onClick)
  }

  disconnect () {
    this.element.removeEventListener('click', this._onClick)
    this.accordion?.destroy()
    this.accordion = null
  }

  openItem (item) {
    this.accordion?.open(item)
  }

  isItemOpen (item) {
    return !!this.accordion?.isOpen(item)
  }
}
