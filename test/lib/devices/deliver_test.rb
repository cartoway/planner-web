require 'test_helper'

class DeliverTest < ActionController::TestCase

  setup do
    @customer = customers(:customer_one)
    @customer.update devices: { deliver: { enable: true } }, enable_vehicle_position: true, enable_proofs: true
    @service = Planner::Application.config.devices.deliver
  end

  test 'should send route' do
    assert_nothing_raised do
      @service.send_route @customer, routes(:route_one_one)
    end
  end

  test 'deliver is send-only (no clear on device definition)' do
    assert_equal [:send], @service.definition[:route_operations]
    assert_not @service.respond_to?(:clear_route)
  end

  test 'deliver fetch_stops is a no-op for planning status' do
    assert_equal [], @service.fetch_stops(@customer, Time.zone.now, plannings(:planning_one))
  end
end
