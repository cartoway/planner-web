require 'test_helper'

class RouteMobileTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include Rails.application.routes.url_helpers

  def app
    Rails.application
  end
  setup do
    @route = routes(:route_one_one)
  end

  test 'should redirect to sign in page if key is invalid' do
    get "routes/#{@route.id}/mobile/?driver_token=bad_key"

    assert last_response.status, 302
    assert_match(/text\/html/, last_response.content_type)
    assert_match(/#{new_user_session_path}/, last_response.location)
  end

  test 'should display the requested page if key is valid' do
    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.status, 200
  end
end
