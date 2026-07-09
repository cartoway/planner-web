# frozen_string_literal: true

require 'test_helper'

class LookbookMountTest < ActionDispatch::IntegrationTest
  MODERN_CHROME_UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

  test 'lookbook UI responds' do
    get '/lookbook', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_match(/lookbook/i, response.body)
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
