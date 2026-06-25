require 'test_helper'

class StopTest < ActiveSupport::TestCase

  test 'should not save' do
    stop = Stop.new
    assert_not stop.save, 'Saved without required fields'
  end

  test 'get order' do
    route = routes(:route_one_one)
    route.planning.customer.enable_orders = true
    assert_not route.stops[0].order
    assert_not route.stops[1].order

    route.planning.apply_orders(order_arrays(:order_array_one), 0)
    route.planning.save!

    assert_equal [products(:product_one), products(:product_two)], route.stops[0].order.products.to_a
    assert route.stops[1].order.products.empty?
  end

  test 'Create Stops With or Without visit_id' do
    route = routes :route_one_one
    assert ActiveRecord::Base.connection.execute "INSERT INTO stops(active, route_id, index, type) VALUES('t', #{route.id}, 1, '#{StopRest.name}');"
    assert_raise ActiveRecord::StatementInvalid do
      assert ActiveRecord::Base.connection.execute "INSERT INTO stops(active, route_id, index, type) VALUES('t', #{route.id}, 1, '#{StopVisit.name}');"
    end
  end

  test 'should return color and icon of stop visit' do
    stop = stops :stop_one_one
    t1 = tags :tag_one

    assert_equal t1.color, stop.color
    assert_nil stop.icon
    assert_nil stop.icon_size
    assert_equal stop.visit.customer.default_destination_icon_size, stop.default_icon_size
  end

  test 'best_open_close strict_within_timewindows compares service end to window close' do
    stop = stops(:stop_one_one)
    # visit_one: time_window_end_11:00, duration 5:33 (333 seconds)
    arrival = Time.zone.parse('2000-01-01 10:58:00').seconds_since_midnight

    _open, _close, late_arrival_only = stop.best_open_close(arrival, strict_within_timewindows: false)
    assert late_arrival_only <= 0, 'arrival before window end should not count as late'

    _open, _close, late_strict = stop.best_open_close(arrival, strict_within_timewindows: true)
    assert late_strict > 0, 'arrival + duration past window end should count as late when strict_within_timewindows'
  end

  test 'should return color and icon of stop rest' do
    stop = stops :stop_one_four
    customer = stop.route.planning.customer

    assert_nil stop.color
    assert_nil stop.icon
    assert_nil stop.icon_size
    assert_equal customer.default_rest_icon, stop.default_icon
    assert_equal customer.default_rest_icon_size, stop.default_icon_size

    store = stores :store_one
    store.color = '#beef'
    store.icon = 'beef'
    store.icon_size = 'small'
    vehicle_usage = stop.route.vehicle_usage
    vehicle_usage.update!(store_rest: store)

    assert_equal store.color, stop.color
    assert_equal store.icon, stop.icon
    assert_equal store.icon_size, stop.icon_size
    assert_equal 'beef', stop.default_icon
    assert_equal 'small', stop.default_icon_size
  end
end
