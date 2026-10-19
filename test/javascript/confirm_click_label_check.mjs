// ponytail: self-check for confirm-click label persistence (run: node test/javascript/confirm_click_label_check.mjs)
// Mirrors labelTextFrom / withIconAndLabel in confirm_click_controller.js

function labelTextFrom (html) {
  const text = String(html || '')
    .replace(/<i\b[^>]*>.*?<\/i>/gis, '')
    .replace(/<[^>]+>/g, ' ')
  return text.replace(/\s+/g, ' ').trim()
}

function withIconAndLabel (iconHtml, label) {
  return label ? `${iconHtml} ${label}` : iconHtml
}

const CHECK = '<i class="fa fa-check fa-fw" aria-hidden="true"></i>'
const SPINNER = '<i class="fa fa-spinner fa-spin fa-fw" aria-hidden="true"></i>'

const labeled = '<i class="fa fa-trash fa-fw"></i><span class="vehicle-usage-btn-label">Supprimer</span>'
const iconOnly = '<i class="fa fa-trash fa-fw"></i>'
const readyCustom = '<i class="fa fa-check fa-fw"></i> Confirmer'

const assert = (cond, msg) => { if (!cond) throw new Error(msg) }

assert(labelTextFrom(labeled) === 'Supprimer', 'extracts button label')
assert(labelTextFrom(iconOnly) === '', 'icon-only has no label')
assert(withIconAndLabel(CHECK, labelTextFrom(labeled)) === `${CHECK} Supprimer`, 'ready keeps label')
assert(withIconAndLabel(SPINNER, labelTextFrom(labeled)) === `${SPINNER} Supprimer`, 'spinner keeps label')
assert(withIconAndLabel(CHECK, labelTextFrom(iconOnly)) === CHECK, 'icon-only stays icon-only')
assert(labelTextFrom(readyCustom) === 'Confirmer', 'custom readyLabel text wins')

console.log('confirm_click_label_check: ok')
