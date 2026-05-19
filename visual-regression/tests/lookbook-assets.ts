// Copyright © Cartoway
// Guardrails: fail fast when Sprockets serves Bootstrap-only CSS (stale public/assets, wrong server).

import { expect, type Page } from '@playwright/test'

export async function assertCartowayStylesheetsLoaded(page: Page): Promise<void> {
  const link = page.locator('link[rel="stylesheet"][href*="layout_bootstrap_overrides"]').first()
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
