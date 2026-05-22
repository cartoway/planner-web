# frozen_string_literal: true

require 'test_helper'

class PlanningStopsPreloadTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @customer = customers(:customer_one)
  end

  test 'full mode when total stops are below both thresholds' do
    @customer.update!(stops_preload_limit: 1000)
    assign_planning_stops_size(500)

    assert_equal :full, PlanningStopsPreload.preload_mode(@planning.reload)
    assert PlanningStopsPreload.preload_stops?(@planning)
  end

  test 'continuous mode between min and max thresholds' do
    @customer.update!(stops_preload_limit: 2000)
    assign_planning_stops_size(1500)

    assert_equal :continuous, PlanningStopsPreload.preload_mode(@planning.reload)
    assert_not PlanningStopsPreload.preload_stops?(@planning)
  end

  test 'continuous mode when limit is below fixed threshold' do
    @customer.update!(stops_preload_limit: 500)
    assign_planning_stops_size(750)

    assert_equal :continuous, PlanningStopsPreload.preload_mode(@planning.reload)
  end

  test 'manual mode when total stops reach the upper threshold' do
    @customer.update!(stops_preload_limit: 1000)
    assign_planning_stops_size(1000)

    assert_equal :manual, PlanningStopsPreload.preload_mode(@planning.reload)
    assert_not PlanningStopsPreload.preload_stops?(@planning)
  end

  test 'manual mode when total stops exceed customer limit above fixed threshold' do
    @customer.update!(stops_preload_limit: 2000)
    assign_planning_stops_size(2500)

    assert_equal :manual, PlanningStopsPreload.preload_mode(@planning.reload)
  end

  private

  def assign_planning_stops_size(total_stops)
    routes = @planning.routes.select { |route| !route.hidden || !route.locked || route.vehicle_usage_id.nil? }.to_a
    per_route = total_stops / routes.size
    remainder = total_stops % routes.size

    routes.each_with_index do |route, index|
      route.route_data.update!(stops_size: per_route + (index < remainder ? 1 : 0))
    end
  end
end
