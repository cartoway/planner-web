# frozen_string_literal: true

require 'test_helper'

class Operations::FetchDeviceStopsStatusTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    Operation.where(customer_id: @customer.id).delete_all
    @customer.update!(enable_stop_status: true, devices: { tomtom: { enable: true, account: 'a', user: 'u', password: 'p' } })
    @operation = Operations::PublishFromPlanning.call(planning: @planning, route_ids: [routes(:route_one_one).id])
    @stop = @operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'writes device status and quantities onto operation stops' do
    unit = deliverable_units(:deliverable_unit_one_two)
    Planner::Application.config.devices.tomtom.stubs(:fetch_stops).returns([
      { order_id: "v#{visits(:visit_one).id}", status: 'Finished', eta: Time.zone.parse('2026-10-05 11:00') },
      {
        order_id: "v#{visits(:visit_one).id}",
        update_quantities: true,
        deliveries: [{ label: unit.label, delivery: '12.5' }]
      }
    ])

    Operations::FetchDeviceStopsStatus.call(operation: @operation)

    @stop.reload
    assert_equal 'Finished', @stop.status
    assert @stop.status_updated_at
    assert_equal 1, @stop.operation_stop_status_events.where(source: 'device').count
    assert_in_delta 12.5, @stop.actual_quantities.dig('deliveries', unit.id.to_s)
  end
end
