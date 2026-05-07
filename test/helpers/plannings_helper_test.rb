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
end
