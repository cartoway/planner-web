# frozen_string_literal: true

require 'test_helper'

class OperationRouteTest < ActiveSupport::TestCase
  teardown do
    Operation.where(customer_id: customers(:customer_one).id).delete_all
  end

  test 'list_depots falls back to usage-set default stores when snapshot is empty' do
    operation = Operations::PublishFromPlanning.call(planning: plannings(:planning_one))
    route = operation.operation_routes.planned.first
    usage = route.vehicle_usage
    set_start = usage.vehicle_usage_set.store_start
    set_stop = usage.vehicle_usage_set.store_stop
    assert set_start
    assert set_stop

    usage.update_columns(store_start_id: nil, store_stop_id: nil)
    route.update_columns(
      vehicle_usage_snapshot: route.vehicle_usage_snapshot.merge('store_start' => {}, 'store_stop' => {})
    )
    route.reload
    usage.reload

    departure, arrival = route.list_depots
    assert_equal set_start.name, departure[:name]
    assert_equal set_stop.name, arrival[:name]
  end

  test 'publish snapshots usage-set default stores on the operation route' do
    usage = vehicle_usages(:vehicle_usage_one_one)
    set_start = usage.vehicle_usage_set.store_start
    usage.update_columns(store_start_id: nil, store_stop_id: nil)
    usage.reload

    operation = Operations::PublishFromPlanning.call(planning: plannings(:planning_one))
    route = operation.operation_routes.find_by!(vehicle_usage_id: usage.id)

    assert_equal set_start.name, route.vehicle_usage_snapshot.dig('store_start', 'name')
  end

  test 'depot_status_events rebuilds atstore then finished from loading stash' do
    operation = Operations::PublishFromPlanning.call(planning: plannings(:planning_one))
    route = operation.operation_routes.planned.first
    day = operation.date
    loading_at = Time.zone.local(day.year, day.month, day.day, 7, 50)
    finished_at = Time.zone.local(day.year, day.month, day.day, 8, 5)
    route.update!(
      departure_status: 'finished',
      departure_status_updated_at: finished_at,
      custom_attributes: { '_departure_loading_at' => loading_at.iso8601 }
    )

    events = route.depot_status_events('start')
    assert_equal %w[atstore finished], events.map { |e| e[:status] }
    assert_equal [loading_at, finished_at], events.map { |e| e[:recorded_at] }
  end
end
