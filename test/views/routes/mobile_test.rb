require 'test_helper'

class RouteMobileTest < ActiveSupport::TestCase
  include Rack::Test::Methods
  include Rails.application.routes.url_helpers

  def app
    Rails.application
  end
  setup do
    @route = routes(:route_one_one)
    @route.planning.update!(date: 1.week.from_now.to_date)
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

  test 'should always show stop visit custom attributes on mobile' do
    visible_attr = custom_attributes(:custom_attribute_stop_one)
    hidden_on_mobile_attr = custom_attributes(:custom_attribute_stop_two)

    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, visible_attr.name
    assert_includes last_response.body, hidden_on_mobile_attr.name
  end

  test 'should show vehicle and route custom attributes visible on mobile' do
    vehicle = @route.vehicle_usage.vehicle
    vehicle.update!(custom_attributes: {
      'custom_attribute_one' => 42,
      'vehicle_info_hidden' => 'secret vehicle info'
    })
    @route.reload.update!(custom_attributes: {
      'route_info_visible' => 'shown route info',
      'route_info_hidden' => 'secret route info'
    })

    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, 'custom_attribute_one'
    assert_includes last_response.body, '42'
    assert_includes last_response.body, 'route_info_visible'
    assert_includes last_response.body, 'shown route info'
    refute_includes last_response.body, 'vehicle_info_hidden'
    refute_includes last_response.body, 'secret vehicle info'
    refute_includes last_response.body, 'route_info_hidden'
    refute_includes last_response.body, 'secret route info'
  end

  test 'should hide visit custom attributes not visible on mobile' do
    visit = visits(:visit_one)
    visit.update!(custom_attributes: {
      'visit_info_visible' => 'shown value',
      'visit_info_hidden' => 'secret value'
    })

    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_includes last_response.body, 'visit_info_visible'
    assert_includes last_response.body, 'shown value'
    refute_includes last_response.body, 'visit_info_hidden'
    refute_includes last_response.body, 'secret value'
  end

  test 'should preserve multiline destination comment on mobile' do
    destination = destinations(:destination_one)
    destination.update!(comment: "Line 1\nLine 2")

    vehicle = @route.vehicle_usage.vehicle
    get "routes/#{@route.id}/mobile/?driver_token=#{vehicle.driver_token}"

    assert last_response.ok?
    assert_match(/wrapped-text/, last_response.body)
    assert_includes last_response.body, 'Line 1'
    assert_includes last_response.body, 'Line 2'
  end
end
