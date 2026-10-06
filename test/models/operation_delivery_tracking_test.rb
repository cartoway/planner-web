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

  test 'preload_visit_stops! loads all destination stops in a constant number of queries' do
    operation = Operations::PublishFromPlanning.call(planning: @planning)
    trackings = operation.operation_delivery_trackings.with_destination.to_a
    skip 'need several destination trackings' if trackings.size < 2

    OperationDeliveryTracking.preload_visit_stops!(trackings)

    stop_queries = 0
    callback = lambda do |_name, _start, _finish, _id, payload|
      stop_queries += 1 if payload[:sql].to_s.include?('operation_stops')
    end

    ActiveSupport::Notifications.subscribed(callback, 'sql.active_record') do
      trackings.each do |tracking|
        assert_kind_of Array, tracking.visit_stops
        assert tracking.visit_stops.first
        assert_equal tracking.destination_id, tracking.visit_stops.first.destination_identity
      end
    end

    assert_equal 0, stop_queries, "expected memoized visit_stops, got #{stop_queries} operation_stops queries"
  end
end
