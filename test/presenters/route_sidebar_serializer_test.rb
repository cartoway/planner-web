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
