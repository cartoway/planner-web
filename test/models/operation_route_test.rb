# frozen_string_literal: true

require 'test_helper'

class OperationRouteTest < ActiveSupport::TestCase
  teardown do
    Operation.where(customer_id: customers(:customer_one).id).delete_all
  end

  test 'list_depots ignores empty store snapshots without loading live usage' do
    operation = publish_operation!(planning: plannings(:planning_one))
    route = operation.operation_routes.planned.first
    route.update_columns(
      vehicle_usage_snapshot: route.vehicle_usage_snapshot.merge('store_start' => {}, 'store_stop' => {})
    )

    departure, arrival = route.reload.list_depots
    assert_nil departure
    assert_nil arrival
  end

  test 'publish snapshots usage-set default stores on the operation route' do
    usage = vehicle_usages(:vehicle_usage_one_one)
    set_start = usage.vehicle_usage_set.store_start
    usage.update_columns(store_start_id: nil, store_stop_id: nil)
    usage.reload

    operation = publish_operation!(planning: plannings(:planning_one))
    route = operation.operation_routes.find_by!(vehicle_usage_id: usage.id)

    assert_equal set_start.name, route.vehicle_usage_snapshot.dig('store_start', 'name')
  end

  test 'depot_status_events rebuilds atstore then finished from loading stash' do
    operation = publish_operation!(planning: plannings(:planning_one))
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
