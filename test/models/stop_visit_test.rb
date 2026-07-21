require 'test_helper'

class StopVisitTest < ActiveSupport::TestCase
  test 'duration and destination_duration apply vehicle coefficients' do
    stop = stops(:stop_one_one)
    vehicle_usage = stop.route.vehicle_usage
    visit = stop.visit
    destination = visit.destination

    base_visit = visit.duration || visit.customer.visit_duration
    destination.update!(duration: 120)
    vehicle_usage.update!(visit_duration_coef: 2, destination_duration_coef: 0.5)

    stop.reload
    assert_equal base_visit, stop.base_duration
    assert_equal 120, stop.base_destination_duration
    assert_equal (base_visit * 2).round, stop.duration
    assert_equal 60, stop.destination_duration
    assert_equal Time.at(stop.duration).utc.strftime('%H:%M:%S'), stop.duration_time_with_seconds
    assert_equal '00:01:00', stop.destination_duration_time_with_seconds
  end

  test 'duration coefficients default to 1 when unset' do
    stop = stops(:stop_one_one)
    stop.route.vehicle_usage.update!(visit_duration_coef: nil, destination_duration_coef: nil)
    stop.route.vehicle_usage.vehicle_usage_set.update!(visit_duration_coef: nil, destination_duration_coef: nil)

    assert_equal 1, stop.visit_duration_coef
    assert_equal 1, stop.destination_duration_coef
    assert_equal stop.base_duration, stop.duration
    assert_equal stop.base_destination_duration, stop.destination_duration
  end
end
