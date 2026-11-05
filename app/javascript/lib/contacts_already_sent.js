// Decide whether a contact row still counts as "already sent" and which channel to use.

export function normalizeContact (value) {
  return String(value || '').trim()
}

// Contact still counts as transmitted only when both fields match the values at last send.
export function effectiveAlreadySent ({ wasSent, originalEmail, originalPhone, email, phone }) {
  if (!wasSent) return false
  return normalizeContact(email) === normalizeContact(originalEmail) &&
    normalizeContact(phone) === normalizeContact(originalPhone)
}

export function channelForAlreadySentRow ({ alreadySent, includeAlreadySent, defaultChannel }) {
  if (alreadySent && !includeAlreadySent) return 'none'
  return defaultChannel || 'none'
}
