// Copyright © Cartoway
// Exclusive accordion: one open item, height slide, pin heading while animating.
// Supports native <details> and Bootstrap-style .collapse.in panels.

export const SLIDE_MS = 200

export function pinDelta (headingTop, stickyTop = 0) {
  return headingTop - stickyTop
}

/** Animate height open/close. openClass is toggled when provided (collapse mode). */
export function slideElement (el, opening, { ms = SLIDE_MS, openClass = null } = {}) {
  if (!el) return
  if (el._slideTimer) window.clearTimeout(el._slideTimer)
  el.style.overflow = 'hidden'
  el.style.transition = `height ${ms}ms ease`
  if (opening) {
    if (openClass) el.classList.add(openClass)
    el.style.height = '0px'
    void el.offsetHeight
    el.style.height = `${el.scrollHeight}px`
    el._slideTimer = window.setTimeout(() => {
      el.style.height = ''
      el.style.overflow = ''
      el.style.transition = ''
      el._slideTimer = null
    }, ms)
    return
  }
  el.style.height = `${el.scrollHeight}px`
  void el.offsetHeight
  el.style.height = '0px'
  el._slideTimer = window.setTimeout(() => {
    if (openClass) el.classList.remove(openClass)
    el.style.height = ''
    el.style.overflow = ''
    el.style.transition = ''
    el._slideTimer = null
  }, ms)
}

export class ExclusiveAccordion {
  constructor ({
    root,
    itemSelector,
    panelSelector,
    headingSelector,
    scrollParent = null,
    stickyTopSelector = null,
    mode = 'details',
    openClass = 'in',
    ms = SLIDE_MS,
    ignoreClickSelector = 'a, button, input, .operation-tour-tools, .no-toggle',
    onOpen = null,
    onCloseAll = null
  }) {
    this.root = root
    this.itemSelector = itemSelector
    this.panelSelector = panelSelector
    this.headingSelector = headingSelector
    this.scrollParent = scrollParent
    this.stickyTopSelector = stickyTopSelector
    this.mode = mode
    this.openClass = openClass
    this.ms = ms
    this.ignoreClickSelector = ignoreClickSelector
    this.onOpen = onOpen
    this.onCloseAll = onCloseAll
    this._pinFrame = null
    this._pinTimer = null
  }

  items () {
    return [...this.root.querySelectorAll(this.itemSelector)]
  }

  panel (item) {
    return item.querySelector(this.panelSelector)
  }

  heading (item) {
    return item.querySelector(this.headingSelector) || item
  }

  isOpen (item) {
    if (this.mode === 'details') return !!item.open
    const panel = this.panel(item)
    return !!(panel && panel.classList.contains(this.openClass))
  }

  destroy () {
    if (this._pinFrame) cancelAnimationFrame(this._pinFrame)
    if (this._pinTimer) window.clearTimeout(this._pinTimer)
    this._pinFrame = null
    this._pinTimer = null
  }

  toggle (item) {
    if (this.isOpen(item)) this.close(item)
    else this.open(item)
  }

  open (item) {
    this.items().forEach((other) => {
      if (other !== item && this.isOpen(other)) this.close(other)
    })
    if (this.mode === 'details') {
      item.open = true
      slideElement(this.panel(item), true, { ms: this.ms, openClass: null })
    } else {
      slideElement(this.panel(item), true, { ms: this.ms, openClass: this.openClass })
    }
    this.trackHeading(this.heading(item))
    this.onOpen?.(item)
  }

  close (item) {
    if (this.mode === 'details') {
      slideElement(this.panel(item), false, { ms: this.ms, openClass: null })
      window.setTimeout(() => {
        item.open = false
        if (!this.items().some((other) => this.isOpen(other))) this.onCloseAll?.()
      }, this.ms)
      return
    }
    slideElement(this.panel(item), false, { ms: this.ms, openClass: this.openClass })
  }

  stickyTop () {
    if (this.stickyTopSelector) {
      const el = document.querySelector(this.stickyTopSelector)
      return el ? Math.max(0, el.getBoundingClientRect().bottom) : 0
    }
    const parent = this.scrollParent
    if (parent && parent !== window) return parent.getBoundingClientRect().top
    return 0
  }

  pinHeading (heading, { smooth = false } = {}) {
    if (!heading) return
    const delta = pinDelta(heading.getBoundingClientRect().top, this.stickyTop())
    if (Math.abs(delta) < 1) return
    const parent = this.scrollParent
    if (parent && parent !== window) parent.scrollTop += delta
    else window.scrollBy({ top: delta, behavior: smooth ? 'smooth' : 'auto' })
  }

  trackHeading (heading) {
    if (!heading) return
    if (this._pinFrame) cancelAnimationFrame(this._pinFrame)
    if (this._pinTimer) window.clearTimeout(this._pinTimer)
    const start = performance.now()
    const tick = (now) => {
      this.pinHeading(heading)
      if (now - start < this.ms) this._pinFrame = requestAnimationFrame(tick)
      else this._pinFrame = null
    }
    this._pinFrame = requestAnimationFrame(tick)
    this._pinTimer = window.setTimeout(() => {
      this.pinHeading(heading, { smooth: true })
      this._pinTimer = null
    }, this.ms)
  }

  /** @returns {boolean} true when the click was handled as an accordion toggle */
  handleClick (event) {
    if (event.target.closest(this.ignoreClickSelector)) return false
    const heading = event.target.closest(this.headingSelector)
    if (!heading || !this.root.contains(heading)) return false
    const item = heading.closest(this.itemSelector)
    if (!item || !this.root.contains(item)) return false
    event.preventDefault()
    this.toggle(item)
    return true
  }
}
