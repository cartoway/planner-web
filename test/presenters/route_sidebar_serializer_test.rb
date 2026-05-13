# frozen_string_literal: true

require 'test_helper'

class RouteSidebarSerializerTest < ActiveSupport::TestCase
  test 'merge_planning_route_errors_from_sidebar_routes ORs flags across routes' do
    routes_data = [
      { route_error: false, route_out_of_window: false, route_no_path: false },
      { route_error: true, route_out_of_window: true, route_no_path: false }
    ]
    RouteSidebarSerializer::ROUTE_ERROR_HASH_KEYS.each do |key|
      routes_data[0][key] = false unless routes_data[0].key?(key)
      routes_data[1][key] = false unless routes_data[1].key?(key)
    end

    merged = RouteSidebarSerializer.merge_planning_route_errors_from_sidebar_routes(routes_data)
    assert merged[:route_out_of_window]
    assert merged[:route_error]
  end

  test 'merge_planning_route_errors_from_sidebar_routes returns empty when no routes' do
    merged = RouteSidebarSerializer.merge_planning_route_errors_from_sidebar_routes([])
    assert_equal false, merged[:route_error]
    RouteSidebarSerializer::ROUTE_ERROR_HASH_KEYS.each do |key|
      assert_equal false, merged[key], "expected #{key} to be false"
    end
  end

  test 'planning_stops_totals sums route_data from all routes' do
    rd1 = Struct.new(:stops_size, :size_active).new(3, 2)
    rd2 = Struct.new(:stops_size, :size_active).new(5, 1)
    r_nil = Struct.new(:route_data).new(nil)
    r1 = Struct.new(:route_data).new(rd1)
    r2 = Struct.new(:route_data).new(rd2)
    planning = Struct.new(:routes).new([r1, r2, r_nil])
    totals = RouteSidebarSerializer.planning_stops_totals(planning)
    assert_equal 8, totals[:size]
    assert_equal 3, totals[:size_active]
  end

  test 'planning_stops_totals matches sum over all planning routes' do
    planning = plannings(:planning_one)
    totals = RouteSidebarSerializer.planning_stops_totals(planning)
    expected_size = planning.routes.sum { |r| r.route_data&.stops_size.to_i }
    expected_active = planning.routes.sum { |r| r.route_data&.size_active.to_i }
    assert_equal expected_size, totals[:size]
    assert_equal expected_active, totals[:size_active]
  end

  test 'planning_stops_totals_for_routes sums only given routes' do
    planning = plannings(:planning_one)
    routes = planning.routes.to_a
    skip 'need at least two routes' if routes.size < 2

    subset = routes.first(1)
    partial = RouteSidebarSerializer.planning_stops_totals_for_routes(subset)
    full = RouteSidebarSerializer.planning_stops_totals_for_routes(routes)
    assert_operator partial[:size], :<=, full[:size]
    assert_equal(
      subset.sum { |r| r.route_data&.stops_size.to_i },
      partial[:size]
    )
  end

  test 'merge_planning_route_errors_from_models reads route attribute methods' do
    attrs = RouteSidebarSerializer::ROUTE_ERROR_HASH_KEYS.index_with { false }.merge(route_out_of_window: true)
    fake_route = Object.new
    RouteSidebarSerializer::ROUTE_ERROR_HASH_KEYS.each do |key|
      meth = key.to_s.delete_prefix('route_').to_sym
      value = attrs[key]
      fake_route.define_singleton_method(meth) { value }
    end

    merged = RouteSidebarSerializer.merge_planning_route_errors_from_models([fake_route])
    assert merged[:route_out_of_window]
    assert merged[:route_error]
  end
end
