# frozen_string_literal: true

require 'test_helper'

class LookbookMountTest < ActionDispatch::IntegrationTest
  test 'lookbook UI responds' do
    get '/lookbook'

    assert_response :success
    assert_match(/lookbook/i, response.body)
  end

  test 'planning sidebar bootstrap 5 preview renders' do
    get '/lookbook/preview/design_system/planning_sidebar/default'

    assert_response :success
    assert_select 'body.cartoway-v2[data-controller="lookbook-v2"]', 1
    assert_select '#edit-planning.sidebar', 1
    assert_select '.lookbook-planning-sidebar-host', 1
  end
end
