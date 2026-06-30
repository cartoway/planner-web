# frozen_string_literal: true

require 'test_helper'

class RouteDataTest < ActiveSupport::TestCase
  test 'defaults computed route_data fields to safe import values' do
    route_data = RouteData.new

    assert_equal false, route_data.unmanageable_capacity
    assert_equal false, route_data.out_of_capacity
    assert_equal false, route_data.hidden
    assert_equal 0, route_data.size_active
    assert_equal 0, route_data.size_destinations
    assert_equal 0, route_data.size_store_reloads
    assert_equal 0, route_data.stops_size
    assert_equal 0, route_data.size_active_destinations
    assert_equal({}, route_data.max_loads)
    assert_equal false, route_data.import_attributes['unmanageable_capacity']
  end

  test 'duration sums visits rests wait and drive time' do
    route_data = RouteData.new(
      visits_duration: 120,
      rests_duration: 30,
      wait_time: 45,
      drive_time: 60
    )

    assert_equal 255, route_data.duration
  end

  test 'work_duration excludes rests_duration' do
    route_data = RouteData.new(
      visits_duration: 120,
      rests_duration: 30,
      wait_time: 45,
      drive_time: 60
    )

    assert_equal 225, route_data.work_duration
  end
end
