# frozen_string_literal: true

require 'test_helper'

class PlanningsHelperTest < ActionView::TestCase
  include PlanningsHelper

  test 'planning_summary includes planning_id and routes for sidebar / stop popover data' do
    planning = plannings(:planning_one)
    s = planning_summary(planning)
    assert_equal planning.id, s[:planning_id]
    assert s.key?(:routes)
    assert s[:routes].is_a?(Array)
  end

  test 'planning_summary route sizes match persisted route_data' do
    planning = plannings(:planning_one)
    s = planning_summary(planning)
    by_id = s[:routes].index_by { |r| r[:route_id] }
    planning.routes.each do |route|
      row = by_id[route.id]
      rd = route.route_data
      assert_equal rd.stops_size, row[:data][:size]
      assert_equal rd.size_active, row[:data][:size_active]
      assert_equal rd.size_store_reloads, row[:data][:size_store_reloads]
    end
  end

  test 'planning_statistics_routes returns sidebar routes when filter_planning_route_data is enabled' do
    planning = plannings(:planning_one)
    sidebar = planning.routes.available.to_a
    user = users(:user_two)
    user.update!(filter_planning_route_data: true)
    got = planning_statistics_routes(planning, sidebar, user)
    assert_equal sidebar.map(&:id).sort, got.map(&:id).sort
  ensure
    user.update!(filter_planning_route_data: false)
  end

  test 'planning_statistics_routes returns all planning routes when filter_planning_route_data is disabled' do
    planning = plannings(:planning_one)
    sidebar = planning.routes.available.to_a
    user = users(:user_two)
    user.update!(filter_planning_route_data: false)
    got = planning_statistics_routes(planning, sidebar, user)
    assert_equal planning.routes.map(&:id).sort, got.map(&:id).sort
  end
end
