require 'test_helper'

class StopQuantitiesTest < ActiveSupport::TestCase
  test 'formats stop visit load with unit label before value and deltas in parentheses' do
    stop = stops(:stop_one_two)
    visit = stop.visit
    vehicle = stop.route.vehicle_usage.vehicle

    vehicle.update!(capacities: { 1 => 3.0, 999 => 1.0 })
    visit.update!(pickups: { 1 => 2 }, deliveries: { 1 => 3 })
    stop.reload.update!(loads: { 1 => 10 })

    loads = StopQuantities.normalize(stop.reload, vehicle.reload)

    assert_equal 1, loads.size
    expected = "L\u202F10/3 (+2) (-3)"
    assert_equal expected, loads.first[:quantity_formatted]
  end
end
