// Copyright © Cartoway
// Lookbook preview paths: Lookbook drops the `Preview` suffix from the Ruby class name for the URL segment.

import { test, expect } from '@playwright/test'
import { assertCartowayStylesheetsLoaded, waitForLookbookFonts } from './lookbook-assets'

const LOOKBOOK_PREVIEWS: { path: string; name: string }[] = [
  { path: 'design_system/foundation/default', name: 'foundation-default' },
  { path: 'design_system/foundation/typography', name: 'foundation-typography' },
  { path: 'design_system/foundation/color_surfaces', name: 'foundation-color_surfaces' },
  { path: 'design_system/buttons/variants', name: 'buttons-variants' },
  { path: 'design_system/buttons/sizes_and_states', name: 'buttons-sizes_and_states' },
  { path: 'design_system/buttons/icon_and_toolbar', name: 'buttons-icon_and_toolbar' },
  { path: 'design_system/buttons/button_groups', name: 'buttons-button_groups' },
  { path: 'design_system/forms/text_fields', name: 'forms-text_fields' },
  { path: 'design_system/forms/input_groups', name: 'forms-input_groups' },
  { path: 'design_system/forms/checks_and_switches', name: 'forms-checks_and_switches' },
  { path: 'design_system/forms/selects_and_textareas', name: 'forms-selects_and_textareas' },
  { path: 'design_system/forms/validation', name: 'forms-validation' },
  { path: 'design_system/feedback/alerts', name: 'feedback-alerts' },
  { path: 'design_system/feedback/badges_and_pills', name: 'feedback-badges_and_pills' },
  { path: 'design_system/feedback/progress_and_spinners', name: 'feedback-progress_and_spinners' },
  { path: 'design_system/navigation/breadcrumbs', name: 'navigation-breadcrumbs' },
  { path: 'design_system/navigation/tabs', name: 'navigation-tabs' },
  { path: 'design_system/navigation/pagination', name: 'navigation-pagination' },
  { path: 'design_system/overlays/modal', name: 'overlays-modal' },
  { path: 'design_system/overlays/dropdown', name: 'overlays-dropdown' },
  { path: 'design_system/overlays/offcanvas', name: 'overlays-offcanvas' },
  { path: 'design_system/tables/destinations_list', name: 'tables-destinations_list' },
  { path: 'design_system/tables/compact_and_striped', name: 'tables-compact_and_striped' },
  { path: 'design_system/grid_layout/rows_and_columns', name: 'grid_layout-rows_and_columns' },
  { path: 'design_system/grid_layout/gutters_and_nesting', name: 'grid_layout-gutters_and_nesting' },
  { path: 'design_system/grid_layout/breakpoints_and_offset', name: 'grid_layout-breakpoints_and_offset' },
  { path: 'design_system/layout_chrome/cards_and_placeholder', name: 'layout_chrome-cards_and_placeholder' },
  { path: 'design_system/layout_chrome/list_group', name: 'layout_chrome-list_group' },
  { path: 'design_system/layout_chrome/form_sidebar_chrome', name: 'layout_chrome-form_sidebar_chrome' },
  { path: 'design_system/planning_sidebar/default', name: 'planning_sidebar-default' }
]

for (const { path, name } of LOOKBOOK_PREVIEWS) {
  test(`lookbook: ${name}`, async ({ page }) => {
    const url = `/lookbook/preview/${path}`
    await page.goto(url, { waitUntil: 'load' })
    await expect(page.locator('body')).toBeVisible()
    await assertCartowayStylesheetsLoaded(page)
    await waitForLookbookFonts(page)
    await expect(page.locator('body')).toHaveScreenshot(`${name}.png`, { timeout: 60_000 })
  })
}
