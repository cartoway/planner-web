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

  test 'filtered search preview renders' do
    get '/lookbook/preview/design_system/forms/filtered_search', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select '[data-controller="v2--filtered-search"]', 1
    assert_select '#lookbook-filtered-search[role="combobox"]', 1
    assert_select 'label[for="lookbook-filtered-search"]', text: I18n.t('destinations.index.search_label')
    assert_select '#lookbook-filtered-search-dropdown [data-search-key]', DestinationSearchParser::ALLOWED_KEYS.size
  end

  test 'destinations list preview renders v2 list frame' do
    get '/lookbook/preview/design_system/tables/destinations_list', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_select 'turbo-frame#destinations_list', 1
    assert_select '.destinations-sidebar', 2
    assert_select '#destination_box.destinations-list-scroll', 1
    assert_select 'th.destinations-selection-col', 1
    assert_select '.destinations-list-geocoding-cell', minimum: 1
    assert_select 'tbody tr.destination', minimum: 1
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
