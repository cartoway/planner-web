# frozen_string_literal: true

require 'test_helper'

class OperationsMapGeojsonTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @operation_route = @operation.operation_routes.find_by!(route_id: routes(:route_one_one).id)
  end

  teardown do
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'route line follows route_geojson polylines' do
    encoded = '_ibE_seK_seK_seK'
    assert_equal [{ 'polylines' => encoded }], @operation_route.route_snapshot['tracks']

    geojson = Operations::MapGeojson.call(operation: @operation, routes: [@operation_route])
    line = geojson[:features].find { |feature| feature[:properties][:geometry_kind] == 'route' }
    expected = FastPolylines.decode(encoded, 6).map { |lat, lng| [lng.to_f, lat.to_f] }

    assert line
    assert_equal expected, line[:geometry][:coordinates]
    assert expected.size >= 2
  end

  test 'finished stops fade the prefix of the planned line' do
    stops = @operation_route.operation_stops.executable.where.not(kind: 'rest').order(:index).to_a
    stops.first.update_columns(status: 'delivered')

    geojson = Operations::MapGeojson.call(operation: @operation.reload, routes: [@operation_route.reload])
    lines = geojson[:features].select { |feature| feature[:properties][:geometry_kind] == 'route' }

    assert_equal 2, lines.size
    assert_equal Operations::MapGeojson::OPACITY_MIN, lines.first[:properties][:opacity]
    assert_equal Operations::MapGeojson::OPACITY_MAX, lines.last[:properties][:opacity]
    assert_equal lines.first[:geometry][:coordinates].last, lines.last[:geometry][:coordinates].first
  end

  test 'treated stop markers use the faded opacity' do
    stop = @operation_route.operation_stops.executable.where.not(kind: 'rest').order(:index).first
    stop.update_columns(status: 'delivered')

    geojson = Operations::MapGeojson.call(operation: @operation.reload, routes: [@operation_route.reload])
    point = geojson[:features].find { |feature| feature.dig(:properties, :operation_stop_id) == stop.id }

    assert point
    assert point[:properties][:treated]
    assert_equal 'delivered', point[:properties][:phase]
    assert_equal Operations::MapGeojson::OPACITY_MIN, point[:properties][:opacity]

    stop.update_columns(status: 'exception')
    geojson = Operations::MapGeojson.call(operation: @operation.reload, routes: [@operation_route.reload])
    anomaly = geojson[:features].find { |feature| feature.dig(:properties, :operation_stop_id) == stop.id }
    assert_equal 'exception', anomaly[:properties][:phase]
    assert_equal 1, @operation_route.board[:exception]
    assert_equal 0, @operation_route.board[:failed]
  end

  test 'depot coordinates are drawn as points' do
    depot = @operation_route.list_depots.compact.find { |place| place[:lat].present? && place[:lng].present? }
    assert depot

    geojson = Operations::MapGeojson.call(operation: @operation, routes: [@operation_route])
    point = geojson[:features].find { |feature| feature.dig(:properties, :kind) == 'depot' && feature.dig(:properties, :label) == depot[:name] }

    assert point
    assert_equal [depot[:lng].to_f, depot[:lat].to_f], point[:geometry][:coordinates]
    refute point[:properties][:returns_complete]
    refute point[:properties].key?(:color)
  end

  test 'a depot place turns complete only when every existing return there is finished' do
    routes = @operation.operation_routes.active_sync.to_a
    without_end = routes.first
    without_end.update_columns(vehicle_usage_snapshot: without_end.vehicle_usage_snapshot.merge('store_stop' => {}), arrival_status: nil)
    returning = routes.drop(1)
    assert returning.any?

    geojson = Operations::MapGeojson.call(operation: @operation, routes: routes.map(&:reload))
    ends = geojson[:features].select { |feature| feature.dig(:properties, :depot_role) == 'end' }
    assert ends.any?
    assert ends.none? { |feature| feature.dig(:properties, :operation_route_id) == without_end.id }
    assert ends.none? { |feature| feature.dig(:properties, :returns_complete) }

    returning.each { |route| route.update_columns(arrival_status: 'delivered') }
    geojson = Operations::MapGeojson.call(operation: @operation, routes: routes.map(&:reload))
    ends = geojson[:features].select { |feature| feature.dig(:properties, :depot_role) == 'end' }
    assert ends.none? { |feature| feature.dig(:properties, :returns_complete) }

    returning.each { |route| route.update_columns(arrival_status: 'finished') }
    geojson = Operations::MapGeojson.call(operation: @operation, routes: routes.map(&:reload))
    ends = geojson[:features].select { |feature| feature.dig(:properties, :depot_role) == 'end' }
    assert ends.all? { |feature| feature.dig(:properties, :returns_complete) }
  end

  test 'mobile positions stay a simplified trace' do
    older = Time.zone.parse('2026-09-25 08:00')
    newer = Time.zone.parse('2026-09-25 09:00')
    VehiclePositions::Record.call(operation_route: @operation_route, lat: 48.0, lng: 2.0, positioned_at: older)
    VehiclePositions::Record.call(operation_route: @operation_route, lat: 48.2, lng: 2.2, positioned_at: newer)

    geojson = Operations::MapGeojson.call(operation: @operation, routes: [@operation_route])
    gps = geojson[:features].find { |feature| feature[:properties][:geometry_kind] == 'positions' }
    route_line = geojson[:features].find { |feature| feature[:properties][:geometry_kind] == 'route' }

    assert_equal [[2.0, 48.0], [2.2, 48.2]], gps[:geometry][:coordinates]
    refute_equal gps[:geometry][:coordinates], route_line[:geometry][:coordinates]
  end
end
