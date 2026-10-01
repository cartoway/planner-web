# frozen_string_literal: true

require 'test_helper'

class PlanningDestinationSmsGoneTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:user_one)
    @planning = plannings(:planning_one)
  end

  test 'planning send_sms destinations endpoint is gone' do
    get "/api/0.1/plannings/#{@planning.id}/send_sms", params: { api_key: @user.api_key }
    assert_response :gone
  end
end
