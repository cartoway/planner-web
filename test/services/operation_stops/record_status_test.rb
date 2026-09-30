# frozen_string_literal: true

require 'test_helper'

class RecordStatusTest < ActiveSupport::TestCase
  include ActionCable::TestHelper
  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @stop = @operation.operation_stops.find_by!(visit_id: visits(:visit_one).id)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'keeps the full timeline and does not regress the cursor' do
    t1 = Time.zone.parse('2026-09-25 10:00')
    t2 = Time.zone.parse('2026-09-25 11:00')
    t0 = Time.zone.parse('2026-09-25 09:00')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'started', recorded_at: t1, source: 'mobile')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'delivered', recorded_at: t2, source: 'mobile')
    OperationStops::RecordStatus.call(operation_stop: @stop, status: 'planned', recorded_at: t0, source: 'mobile')

    @stop.reload
    assert_equal %w[planned started delivered], @stop.operation_stop_status_events.order(:recorded_at).pluck(:status)
    assert_equal 'delivered', @stop.status
    assert_equal t2, @stop.status_updated_at
    assert_nil @stop.stop.reload.status
  end

  test 'refreshes the operation page when a stop advances' do
    operation = @stop.operation_route.operation
    assert_broadcasts(operation.to_gid_param, 1) do
      OperationStops::RecordStatus.call(operation_stop: @stop, status: 'delivered', recorded_at: Time.zone.parse('2026-09-25 11:00'), source: 'mobile')
    end
  end

  test 'board sums late minutes and ignores early arrivals' do
    route = @operation.operation_routes.includes(:operation_stops).detect { |candidate|
      candidate.operation_stops.count { |stop| stop.kind == 'visit' && stop.stop_snapshot['time'].present? } >= 2
    }
    assert route
    late, early = route.operation_stops.select { |stop| stop.kind == 'visit' && stop.stop_snapshot['time'].present? }.first(2)
    date = @operation.date
    late_planned = Time.zone.local(date.year, date.month, date.day) + late.stop_snapshot['time'].to_i
    early_planned = Time.zone.local(date.year, date.month, date.day) + early.stop_snapshot['time'].to_i
    late.update_columns(status: 'delivered', status_updated_at: late_planned + 10.minutes)
    early.update_columns(status: 'delivered', status_updated_at: early_planned - 8.minutes)

    assert_equal 10, route.board[:delay]
  end
end
