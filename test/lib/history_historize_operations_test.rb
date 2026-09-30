# frozen_string_literal: true

require 'test_helper'
require 'history'

class HistoryHistorizeOperationsTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = @planning.customer
    @customer.update!(history_cron_hour: 10)
  end

  teardown do
    Operation.where(customer_id: @customer.id).delete_all
    HistoryStop.where(customer_id: @customer.id).delete_all
  end

  test 'publish snapshots include planned route and stop fields without status' do
    operation = Operations::PublishFromPlanning.call(planning: @planning, date: '2026-09-30', name: 'Snap')
    route = operation.operation_routes.planned.first
    stop = route.operation_stops.find { |row| row.kind == 'visit' }

    assert route.route_snapshot.key?('pickups')
    assert route.route_snapshot.key?('deliveries')
    assert route.route_snapshot.key?('departure')
    assert stop.stop_snapshot.key?('out_of_window')
    assert stop.stop_snapshot.key?('distance')
    assert_nil stop.stop_snapshot['status']
    assert_nil stop.stop_snapshot['eta']
    assert_nil stop.stop_snapshot['status_updated_at']
  end

  test 'to_history_stops uses operation status not planning live status' do
    operation = Operations::PublishFromPlanning.call(planning: @planning, date: '2026-09-30', name: 'Map')
    route = operation.operation_routes.planned.first
    stop = route.operation_stops.find { |row| row.kind == 'visit' }
    live = stop.stop
    live.update_columns(status: 'planning-live', status_updated_at: 2.days.ago) if live

    at = Time.zone.parse('2026-09-30 14:00:00')
    stop.update_columns(status: 'delivered', status_updated_at: at, eta: at)
    route.update_columns(departure_status: 'departed', departure_eta: at, arrival_status: 'arrived', arrival_eta: at)

    row = Operations::ToHistoryStops.rows(operation, hourly: true).find { |r| r[:route_id] == route.route_id }
    assert row
    assert_equal 'delivered', row[:stops].first['stop']['status']
    assert_equal at.to_i, row[:stops].first['stop']['status_updated_at'].to_i
    assert_equal 'departed', row[:start_route_data]['status']
    assert_equal 'arrived', row[:stop_route_data]['status']
    assert_equal route.vehicle_snapshot['name'], row[:vehicle]['name']
    assert row[:route_data].key?('distance') || row[:route_data].key?('drive_time') || row[:route_data].present?
  end

  # Hawaii (fixture users) is UTC-10 → local 10:00 = 20:00 UTC
  test 'hourly cron historizes by operation date and writes history_stops' do
    travel_to Time.utc(2026, 9, 30, 20, 5, 0) do
      @planning.update!(date: Date.new(2026, 1, 1))
      route_ids = @planning.routes.where.not(vehicle_usage_id: nil).order(:id).pluck(:id)
      assert_operator route_ids.size, :>=, 2

      matching = Operations::PublishFromPlanning.call(
        planning: @planning, date: '2026-09-30', name: 'Match', route_ids: [route_ids.first]
      )
      other = Operations::PublishFromPlanning.call(
        planning: @planning, date: '2026-01-01', name: 'Other', route_ids: [route_ids.last]
      )

      stop = matching.operation_routes.planned.first.operation_stops.find { |row| row.kind == 'visit' }
      stop.update_columns(status: 'delivered', status_updated_at: Time.current)

      History.historize(true, nil)

      assert_equal 'historized', matching.reload.status
      assert_equal 'in_progress', other.reload.status

      history = HistoryStop.where(customer_id: @customer.id, planning_id: @planning.id)
                           .where('date_trunc(\'day\', date) = ?', Date.new(2026, 9, 30))
                           .to_a
      assert history.any?
      payload_status = history.flat_map { |h| Array(h.stops).map { |s| s.dig('stop', 'status') } }
      assert_includes payload_status, 'delivered'
    end
  end
end
