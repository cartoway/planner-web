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
  end

  test 'should return color and icon of stop rest' do
    stop = stops :stop_one_four

    assert_nil stop.color
    assert_nil stop.icon
    assert_nil stop.icon_size

    store = stores :store_one
    store.color = '#beef'
    store.icon = 'beef'
    assert store.color, stop.color
    assert store.icon, stop.icon
    assert_nil stop.icon_size
  end
end
