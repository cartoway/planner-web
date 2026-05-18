# frozen_string_literal: true

require 'test_helper'

class LookbookMountTest < ActionDispatch::IntegrationTest
  test 'lookbook UI responds' do
    get '/lookbook'

    assert_response :success
    assert_match(/lookbook/i, response.body)
  end
end
