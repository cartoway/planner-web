// Copyright © Cartoway
// History updates for v2 form_sidebar: form path while open, list path when closed.

export function formSidebarPageKey (href, base = 'http://localhost/') {
  const url = new URL(String(href), base)
  return `${url.pathname}${url.search}`
}

export function formSidebarHistoryUpdate ({ currentHref, frameSrc, listUrl, hasForm, fromPopstate, base }) {
  if (fromPopstate) return null
  const current = formSidebarPageKey(currentHref, base)
  if (hasForm && frameSrc) {
    const next = formSidebarPageKey(frameSrc, base)
    if (current === next) return null
    return { type: 'push', url: next, formSidebar: true }
  }
  if (!hasForm && listUrl) {
    const next = formSidebarPageKey(listUrl, base)
    if (current === next) return null
    return { type: 'push', url: next, formSidebar: false }
  }
  return null
}
