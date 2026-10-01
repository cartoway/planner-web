# frozen_string_literal: true

require 'test_helper'

class OperationDeliveryTrackingTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'ensure_for! creates one tracking per visit destination' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)

    destination_ids = operation.operation_stops.executable.where(kind: 'visit').filter_map { |stop|
      stop.destination_id.presence || stop.destination_snapshot&.[]('id')
    }.uniq

    assert_operator destination_ids.size, :>, 0
    assert_equal destination_ids.sort, operation.operation_delivery_trackings.pluck(:destination_id).sort
  end

  test 'ensure_for! is a no-op when the table is missing' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    OperationDeliveryTracking.where(operation_id: operation.id).delete_all
    OperationDeliveryTracking.connection.stubs(:table_exists?).returns(false)

    assert_nothing_raised { OperationDeliveryTracking.ensure_for!(operation) }
    assert_equal 0, OperationDeliveryTracking.where(operation_id: operation.id).count
  end
end
