// Copyright © Cartoway
// Non-blocking list filter: yields between chunks so the input stays responsive.

export const DEFAULT_CHUNK_SIZE = 48

export function normalizeFilterQuery (value) {
  return String(value || '').trim().toLowerCase()
}

/**
 * Apply a text filter to items in scheduled chunks.
 * Returns a cancel function — call it before starting a new run.
 */
export function scheduleListFilter ({
  items,
  query,
  getText,
  setVisible,
  onDone,
  chunkSize = DEFAULT_CHUNK_SIZE,
  schedule = (fn) => requestAnimationFrame(fn)
}) {
  const q = normalizeFilterQuery(query)
  let cancelled = false
  let i = 0
  let visibleCount = 0
  const list = items

  const step = () => {
    if (cancelled) return
    const end = Math.min(i + chunkSize, list.length)
    for (; i < end; i++) {
      const item = list[i]
      const show = !q || getText(item).includes(q)
      setVisible(item, show)
      if (show) visibleCount++
    }
    if (i < list.length) {
      schedule(step)
      return
    }
    onDone?.(visibleCount)
  }

  schedule(step)
  return () => { cancelled = true }
}
