# frozen_string_literal: true

require 'test_helper'

class LookbookMountTest < ActionDispatch::IntegrationTest
  MODERN_CHROME_UA = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'

  test 'lookbook UI responds' do
    get '/lookbook', headers: { 'User-Agent' => MODERN_CHROME_UA }

    assert_response :success
    assert_match(/lookbook/i, response.body)
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
    assert_select '#lookbook-filtered-search[placeholder=?]', I18n.t('destinations.index.search_placeholder', name_key: I18n.t('destinations.index.search_keys.name'), city_key: I18n.t('destinations.index.search_keys.city'))
    assert_select 'label[for="lookbook-filtered-search"]', text: I18n.t('destinations.index.search_label')
    assert_select '#lookbook-filtered-search-dropdown [data-search-key]', DestinationSearchParser::ALLOWED_KEYS.size
  end
end
