# frozen_string_literal: true

require 'test_helper'

class ExecutionWriteGuardTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @operation = publish_operation!(planning: @planning)
    @stop = @operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
    @route = @stop.operation_route
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'allows status writes while the operation is open' do
    OperationStops::RecordStatus.call(
      operation_stop: @stop,
      status: 'delivered',
      recorded_at: Time.zone.parse('2026-10-16 10:00'),
      source: 'mobile'
    )
    assert_equal 'delivered', @stop.reload.status
  end

  test 'allows offline flush recorded before closed_at on a historized operation' do
    closed_at = Time.zone.parse('2026-10-16 12:00')
    @operation.update!(status: 'historized', closed_at: closed_at)

    OperationStops::RecordStatus.call(
      operation_stop: @stop,
      status: 'delivered',
      recorded_at: closed_at - 5.minutes,
      source: 'mobile'
    )
    assert_equal 'delivered', @stop.reload.status
  end

  test 'rejects execution writes after the twelve hour grace window' do
    closed_at = Time.zone.parse('2026-10-16 12:00')
    @operation.update!(status: 'historized', closed_at: closed_at)

    assert_raises(ActiveRecord::StatementInvalid) do
      OperationStops::RecordStatus.call(
        operation_stop: @stop,
        status: 'delivered',
        recorded_at: closed_at + 13.hours,
        source: 'mobile'
      )
    end
    assert_nil @stop.reload.status
  end

  test 'allows snapshot-only updates on a historized operation' do
    @operation.update!(status: 'historized', closed_at: 2.days.ago)
    snap = @stop.visit_snapshot.merge('comment' => 'sync refresh')

    assert_nothing_raised do
      @stop.update!(visit_snapshot: snap)
    end
    assert_equal 'sync refresh', @stop.reload.visit_snapshot['comment']
  end

  test 'rejects depot status writes after the grace window' do
    closed_at = Time.zone.parse('2026-10-16 12:00')
    @operation.update!(status: 'historized', closed_at: closed_at)

    assert_raises(ActiveRecord::StatementInvalid) do
      @route.update!(
        departure_status: 'atstore',
        departure_status_updated_at: closed_at + 13.hours
      )
    end
    assert_nil @route.reload.departure_status
  end
end
