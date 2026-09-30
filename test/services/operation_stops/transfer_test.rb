# frozen_string_literal: true

require 'test_helper'

class OperationStopsTransferTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @source_route = @operation.operation_routes.find_by!(route_id: routes(:route_one_one).id)
    @target_route = @operation.operation_routes.planned.where.not(id: @source_route.id).detect { |route| route.route_id.present? }
    skip 'Need a second vehicle route in the operation' unless @target_route
    @stop = @source_route.operation_stops.find_by!(visit_id: visits(:visit_one).id)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'moves the operation stop and records transferred status without touching planning' do
    from_name = @source_route.vehicle_name
    to_name = @target_route.vehicle_name
    planning_stop = Stop.find(@stop.stop_id)
    planning_route_id = planning_stop.route_id

    OperationStops::Transfer.call(
      operation_stop: @stop,
      target_operation_route: @target_route,
      recorded_at: Time.zone.parse('2026-09-25 12:00'),
      source: 'mobile'
    )

    @stop.reload
    assert_equal @target_route.id, @stop.operation_route_id
    assert_equal 'transferred', @stop.status
    event = @stop.operation_stop_status_events.order(:recorded_at).last
    assert_equal 'transferred', event.status
    assert_equal from_name, event.payload['from_route_name']
    assert_equal to_name, event.payload['to_route_name']
    assert_nil @stop.actual_clock
    assert_nil @stop.delay_minutes

    planning_stop.reload
    assert_equal planning_route_id, planning_stop.route_id
  end
end
