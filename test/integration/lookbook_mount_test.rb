# frozen_string_literal: true

require 'test_helper'

class LookbookMountTest < ActionDispatch::IntegrationTest
  MODERN_CHROME_UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

  test 'lookbook UI responds' do
    get '/lookbook', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_match(/lookbook/i, response.body)
  end

  test 'lookbook visual regression report preview renders when manifest is missing' do
    public_dir = Rails.root.join('public/lookbook-visual-regression')
    FileUtils.rm_rf(public_dir)

    get '/lookbook/preview/design_system/visual_regression/report', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_match(/Visual regression/i, response.body)
    assert_match I18n.t('lookbook_visual_regression.no_report_title'), response.body
  end

  test 'lookbook visual regression report uses main-app accept URLs when VRT is enabled' do
    @previous_vrt = ENV.fetch('LOOKBOOK_VRT', nil)
    ENV['LOOKBOOK_VRT'] = '1'
    public_dir = Rails.root.join('public/lookbook-visual-regression')
    FileUtils.mkdir_p(public_dir)
    File.write(
      public_dir.join('manifest.json'),
      {
        generated_at: Time.zone.now.iso8601,
        status: 'failed',
        passed_count: 0,
        failed_count: 1,
        previews: [
          {
            name: 'foundation-default',
            path: 'design_system/foundation/default',
            status: 'failed',
            expected_url: '/lookbook-visual-regression/foundation-default-expected.png',
            actual_url: '/lookbook-visual-regression/foundation-default-actual.png',
            diff_url: '/lookbook-visual-regression/foundation-default-diff.png',
            lookbook_preview_url: '/lookbook/preview/design_system/foundation/default'
          }
        ]
      }.to_json
    )

    get '/lookbook/preview/design_system/visual_regression/report', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_includes response.body, "data-lookbook-visual-regression-accept-url-value='/lookbook/visual_regression/accept'"
    assert_includes response.body, "data-lookbook-visual-regression-accept-all-url-value='/lookbook/visual_regression/accept_all'"
    assert_not_includes response.body, '/lookbook/lookbook/visual_regression/'
    assert_not_includes response.body, '&gt;lookbook-visual-regression'
  ensure
    ENV['LOOKBOOK_VRT'] = @previous_vrt
    FileUtils.rm_rf(public_dir)
  end

  test 'lookbook visual regression report preview renders when manifest exists' do
    public_dir = Rails.root.join('public/lookbook-visual-regression')
    FileUtils.mkdir_p(public_dir)
    File.write(
      public_dir.join('manifest.json'),
      {
        generated_at: Time.zone.now.iso8601,
        status: 'passed',
        passed_count: 1,
        failed_count: 0,
        previews: [
          {
            name: 'foundation-default',
            path: 'design_system/foundation/default',
            status: 'passed',
            expected_url: nil,
            actual_url: nil,
            diff_url: nil,
            lookbook_preview_url: '/lookbook/preview/design_system/foundation/default'
          }
        ]
      }.to_json
    )

    get '/lookbook/preview/design_system/visual_regression/report', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_match(/Visual regression/i, response.body)
    assert_match(/foundation-default/, response.body)
  ensure
    FileUtils.rm_rf(public_dir)
  end

  test 'lookbook preview includes v2 layout_bootstrap_overrides stylesheet' do
    get '/lookbook/preview/design_system/foundation/default', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select 'link[rel="stylesheet"][href*="layout_bootstrap_overrides"]', 1
    assert_select 'body.cartoway-v2[data-controller="lookbook-v2"]', 1
  end

  test 'planning sidebar bootstrap 5 preview renders' do
    get '/lookbook/preview/design_system/planning_sidebar/default', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select 'body.cartoway-v2[data-controller="lookbook-v2"]', 1
    assert_select '#edit-planning.sidebar', 1
    assert_select '.lookbook-planning-sidebar-host', 1
  end

  test 'operation desk preview renders' do
    get '/lookbook/preview/design_system/operation/default', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '.operation-board', 1
    assert_select '.operation-chip', text: /#{Regexp.escape(I18n.t('operations.show.filter_exception'))}/
    assert_select '.operation-glyph.is-exception', 1
    assert_select '.operation-glyph.is-failed', 1
    assert_select '.lookbook-operation-map', 1
  end

  test 'index with cards preview renders' do
    get '/lookbook/preview/design_system/index_cards/index_with_cards', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '.lookbook-index-cards-host', 1
    assert_select '.v2-index-cards', minimum: 2
    assert_select '.v2-index-card', minimum: 2
    assert_select '.v2-index-card-title', text: 'Morning round'
    assert_select '.lookbook-deliverable-units-cards .v2-index-card-meta-label', minimum: 1
  end

  test 'index with cards mobile preview renders phone frames' do
    get '/lookbook/preview/design_system/index_cards/index_with_cards_mobile', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '.lookbook-index-cards-mobile', 2
    assert_select '.lookbook-index-cards-mobile-frame', 2
    assert_select '.lookbook-index-cards-mobile-toolbar .fa-check-square', minimum: 2
    assert_select '.lookbook-index-cards-mobile .v2-index-card-actions--slots', minimum: 1
    assert_select '.lookbook-index-cards-mobile .lookbook-deliverable-units-cards .v2-index-card-actions', minimum: 1
    assert_select '.lookbook-index-cards-mobile .v2-index-card-title', text: 'Morning round'
  end

  test 'index cards with_selection preview renders' do
    get '/lookbook/preview/design_system/index_cards/with_selection', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '[data-controller*="v2--index-selection"]', 1
    assert_select '.v2-index-cards', 1
    assert_select '[data-v2--table-selection-target="row"]', 3
    assert_select 'button[data-action*="v2--index-selection#toggle"] .fa-check-square', 1
    assert_select '.v2-index-card-meta-label', minimum: 1
  end

  test 'index with cards and map preview renders desktop panel' do
    get '/lookbook/preview/design_system/index_cards/index_with_cards_and_map', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '.lookbook-index-map-desktop .lookbook-index-list-panel', 1
    assert_select '.lookbook-index-map-desktop .destinations-sidebar-title-row h1', 1
    assert_select '.lookbook-index-map-desktop .destinations-search-icon.fa-magnifying-glass', 1
    assert_select '.lookbook-index-map-desktop .destinations-list-toolbar .fa-check-square', 1
    assert_select '.lookbook-index-map-desktop .v2-index-card', minimum: 1
    assert_select '.lookbook-index-map-desktop .destinations-index-card', minimum: 1
    assert_select '.lookbook-index-map-desktop .destinations-card-address', minimum: 1
    assert_select '.lookbook-index-map-desktop .destinations-card-geocoding-chip', minimum: 1
    assert_select '.lookbook-index-map-desktop .destinations-card-geocoded.alert-light .fa-magnifying-glass', minimum: 1
    assert_select '.lookbook-index-map-desktop .destinations-list-deliverable-unit-label', minimum: 1
    assert_select '.lookbook-index-map-mobile', 0
  end

  test 'index with cards and map mobile preview renders panes' do
    get '/lookbook/preview/design_system/index_cards/index_with_cards_and_map_mobile', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '.lookbook-index-map-desktop', 0
    assert_select '.lookbook-index-map-mobile', 2
    assert_select '.lookbook-index-map-frame.is-mobile-pane-list', 1
    assert_select '.lookbook-index-map-frame.is-mobile-pane-map', 1
    assert_select '.lookbook-index-map-mobile .v2-map-index-mobile-panes .btn', 4
    # Liste pane shows cards only — map placeholder belongs to the Carte pane.
    assert_select '.lookbook-index-map-frame.is-mobile-pane-list .lookbook-index-map-placeholder', 0
    assert_select '.lookbook-index-map-frame.is-mobile-pane-list .v2-index-card', minimum: 1
    assert_select '.lookbook-index-map-frame.is-mobile-pane-map .lookbook-index-map-placeholder', 1
    assert_select '.lookbook-index-map-mobile .destinations-index-card', minimum: 1
  end

  test 'filtered search preview renders' do
    get '/lookbook/preview/design_system/forms/filtered_search', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '[data-controller="v2--filtered-search"]', 1
    assert_select '#lookbook-filtered-search[role="combobox"]', 1
    assert_select '#lookbook-filtered-search[aria-label]', 1
    assert_select '.destinations-search-icon.fa-magnifying-glass', 1
    assert_select 'label[for="lookbook-filtered-search"]', 0
    assert_select '#lookbook-filtered-search-dropdown [data-search-key]', DestinationSearchParser::ALLOWED_KEYS.size
  end

  test 'searchable checklist dropdown preview renders' do
    get '/lookbook/preview/design_system/overlays/searchable_checklist_dropdown', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '[data-controller="v2--searchable-checklist-dropdown"]', 1
    assert_select '.lookbook-searchable-checklist-dropdown-host', 1
    assert_select '.searchable-checklist-dropdown-menu.show', 1
    assert_select '.searchable-checklist-dropdown-toggle[aria-expanded="true"]', 1
    assert_select '.searchable-checklist-dropdown-search input[type=search]', 1
    assert_select '.searchable-checklist-dropdown-option--global button[data-action*="resetDefaults"]', 1
    assert_select '.searchable-checklist-dropdown-checkbox', 12
    assert_select '[data-v2--searchable-checklist-dropdown-max-active-value="5"]', 1
  end

  test 'destinations list preview renders v2 list frame' do
    get '/lookbook/preview/design_system/tables/destinations_list', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select 'turbo-frame#destinations_list', 1
    assert_select '.destinations-sidebar', minimum: 2
    assert_select '.destinations-sidebar-title-row', minimum: 2
    assert_select '#destinations-search-form .destinations-search-icon.fa-magnifying-glass', 1
    assert_select '#destination_box.destinations-list-scroll', 1
    assert_select 'turbo-frame#destinations_list .v2-index-card.destination', minimum: 1
    assert_select 'button.floating-btn.destinations-sidebar-toggle', minimum: 1
    assert_select 'button.floating-btn.destinations-sidebar-expand.slide-panel-expand-trigger', minimum: 1
  end

  test 'form sidebar chrome preview renders slide panel and floating buttons' do
    get '/lookbook/preview/design_system/layout_chrome/form_sidebar_chrome', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '.lookbook-form-sidebar-host', 1
    assert_select 'aside.form-sidebar.slide-panel.slide-panel--from-right', minimum: 1
    assert_select '.form-sidebar-chrome button.btn-close', minimum: 1
    assert_select 'button.floating-btn.form-sidebar-expand.slide-panel-expand-trigger', minimum: 1
    assert_select 'header.destination-form-sidebar-header', minimum: 1
    assert_select '.related-list', minimum: 2
    assert_select '.related-item', minimum: 3
    assert_select '.related-item-index', minimum: 3
    assert_select '.related-item-status.stop-status-delivered', 1
  end

  test 'form sidebar bottom sheet preview renders backdrop and close chrome' do
    get '/lookbook/preview/design_system/layout_chrome/form_sidebar_bottom_sheet', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '.lookbook-form-sidebar-host', 1
    assert_select '#lookbook-form-sidebar-bottom-sheet.lookbook-form-sidebar-demo--bottom-sheet', 1
    assert_select '.form-sidebar-backdrop.is-visible', 1
    assert_select 'aside.form-sidebar.form-sidebar--open.is-open', 1
    assert_select '.form-sidebar-chrome button.btn-close', 1
    assert_select 'header.destination-form-sidebar-header', 1
  end

  test 'grid layout rows and columns preview renders' do
    get '/lookbook/preview/design_system/grid_layout/rows_and_columns', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select 'body.cartoway-v2[data-controller="lookbook-v2"]', 1
    assert_select '.alert.alert-secondary', text: /12 virtual columns/
    assert_select '.row .col-1', 12
  end

  test 'xl floating button preview renders pill floating CTA' do
    get '/lookbook/preview/design_system/layout_chrome/xl_floating_button', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select 'button.floating-btn.xl-floating-button', minimum: 2
    assert_select 'button.floating-btn.xl-floating-button .floating-label', minimum: 2
    assert_select 'button.floating-btn.xl-floating-button .fa.fa-times', minimum: 2
  end
end
