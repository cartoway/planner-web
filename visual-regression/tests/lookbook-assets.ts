// Copyright © Cartoway
// Guardrails: fail fast when Sprockets serves Bootstrap-only CSS (stale public/assets, wrong server).

import { expect, type Page } from '@playwright/test'

export async function assertCartowayStylesheetsLoaded(page: Page): Promise<void> {
  const link = page.locator('link[rel="stylesheet"][href*="layout_bootstrap_overrides"]').first()
  if ((await link.count()) === 0) {
    const url = page.url()
    const title = await page.title()
    throw new Error(
      `layout_bootstrap_overrides stylesheet not found on ${url} (title: ${title}). ` +
        'Expected a Lookbook preview rendered with lookbook_preview layout. ' +
        'If the URL is /unsupported_browser, use a modern Chrome User-Agent or exclude /lookbook from Browser::Middleware.'
    )
  }
  await expect(link).toHaveAttribute('href', /layout_bootstrap_overrides/)

  const href = await link.getAttribute('href')
  if (!href) throw new Error('layout_bootstrap_overrides stylesheet link has no href')

  const cssUrl = new URL(href, page.url()).toString()
  const response = await page.request.get(cssUrl)
  expect(response.ok(), `GET ${cssUrl} failed: ${response.status()}`).toBeTruthy()

  const css = await response.text()
  expect(
    css,
    `${cssUrl} must include Cartoway v2 overrides from layout_bootstrap_overrides / _visual_language.scss`
  ).toContain('body.cartoway-v2 .btn.btn-secondary')
  expect(css).toContain('--bs-btn-bg: #fff')
}

/** Lookbook loads Montserrat from Google Fonts; `document.fonts.ready` alone is not enough. */
export async function waitForLookbookFonts(page: Page): Promise<void> {
  await page.evaluate(async () => {
    const family = 'Montserrat'
    const loads = ['400 13px', '400 1em', '500 1em', '600 1em', '700 1em']
    for (const desc of loads) {
      try {
        await document.fonts.load(`${desc} ${family}`)
      } catch {
        // FontFace load can reject when the family is already loading; keep going.
      }
    }
    await document.fonts.ready
    if (!document.fonts.check('400 13px Montserrat')) {
      throw new Error(
        'Montserrat did not load before screenshot. ≥ and body text metrics will differ from CI (fallback fonts). Check Google Fonts access or regenerate snapshots on CI.'
      )
    }
  })
}
