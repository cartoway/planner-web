require 'test_helper'

class DeliverTest < ActionController::TestCase

  setup do
    @customer = customers(:customer_one)
    @customer.update devices: { deliver: { enable: true } }, enable_vehicle_position: true, enable_stop_status: true
    @service = Planner::Application.config.devices.deliver
  end

  test 'should send route' do
    assert_nothing_raised do
      @service.send_route @customer, routes(:route_one_one)
    end
  end

  test 'should clear route' do
    assert_nothing_raised do
      @service.clear_route @customer, routes(:route_one_one)
    end
  end

  test 'deliver fetch_stops is a no-op for planning status' do
    assert_equal [], @service.fetch_stops(@customer, Time.zone.now, plannings(:planning_one))
  end
end
