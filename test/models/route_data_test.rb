# frozen_string_literal: true

require 'test_helper'

class RouteDataTest < ActiveSupport::TestCase
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
