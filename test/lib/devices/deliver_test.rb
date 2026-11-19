require 'test_helper'

class DeliverTest < ActionController::TestCase

  setup do
    @customer = customers(:customer_one)
    @customer.update devices: { deliver: { enable: true } }, enable_vehicle_position: true, enable_proofs: true
    @service = Planner::Application.config.devices.deliver
  end

  test 'should send operation route by email' do
    planning = plannings(:planning_one)
    operation = publish_operation!(planning: planning, date: Date.current)
    operation_route = operation.operation_routes.planned.first
    operation_route.update!(vehicle_snapshot: operation_route.vehicle_snapshot.merge('contact_email' => 'driver@example.com'))

    assert_difference 'ActionMailer::Base.deliveries.size', 1 do
      @service.send_route @customer, operation_route
    end
  ensure
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'deliver is send-only (no clear on device definition)' do
    assert_equal [:send], @service.definition[:route_operations]
    assert_not @service.respond_to?(:clear_route)
  end

  test 'deliver fetch_stops is a no-op for planning status' do
    assert_equal [], @service.fetch_stops(@customer, Time.zone.now, plannings(:planning_one))
  end
end
