# frozen_string_literal: true

require 'test_helper'

class OperationStopSearchTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    Operation.where(customer_id: @customer.id).delete_all
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
  end

  test 'finds a stop from the snapshot after the destination is gone' do
    destination = destinations(:destination_one)
    destination.delete
    stops = OperationStop.search_by_destination_info(
      query: 'Bordeau',
      from: @operation.date,
      to: @operation.date,
      customer_id: @customer.id
    )
    assert stops.any?
    assert stops.all? { |stop| stop.destination_snapshot['city'] == 'Bordeau' }
    assert stops.all? { |stop| stop.destination_id.nil? }
  end

  test 'hides past operations by default and shows them with include_past' do
    destination = destinations(:destination_one)
    @operation.update_columns(date: Date.yesterday, status: 'historized')
    assert_empty OperationStop.for_destination(destination, include_past: false).where(operation_route_id: @operation.operation_route_ids)
    assert OperationStop.for_destination(destination, include_past: true).where(operation_route_id: @operation.operation_route_ids).any?

    @operation.update_columns(date: Date.current, status: 'in_progress')
    assert OperationStop.for_destination(destination, include_past: false).where(operation_route_id: @operation.operation_route_ids).any?

    @operation.update_columns(date: Date.yesterday, status: 'in_progress')
    assert OperationStop.for_destination(destination, include_past: false).where(operation_route_id: @operation.operation_route_ids).any?
  end
end
