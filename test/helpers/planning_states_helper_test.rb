# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

require 'test_helper'

class PlanningStatesHelperTest < ActionView::TestCase
  include PlanningStatesHelper
  include ApplicationHelper
  include PreferencesHelper

  test 'planning_state_statistics_html renders route data blocks without speed or quantities' do
    statistics = {
      'routes_cost' => 42.5,
      'routes_revenue' => 50.0,
      'routes_drive_time' => 3600,
      'routes_wait_time' => 600,
      'routes_visits_duration' => 1800,
      'routes_rests_duration' => 300,
      'vehicles_used' => 2,
      'vehicles' => 3,
      'distance_total' => 12_500.0,
      'routes_emission' => 1.25,
      'duration_total' => 7200,
      'work_duration_total' => 5400,
      'stops_size' => 10,
      'stops_size_active' => 8
    }

    html = planning_state_statistics_html(statistics, prefered_unit: 'km')

    assert_includes html, 'route-info'
    assert_includes html, 'route-data'
    assert_not_includes html, 'fa-tachometer'
    refute_match(/quantities/, html)
  end

  test 'planning_state_stat_diffs marks lower metrics as success and active stops inverted' do
    state_stats = { 'distance_total' => 10_000.0, 'stops_size_active' => 8 }
    reference_stats = { 'distance_total' => 12_000.0, 'stops_size_active' => 6 }

    diffs = planning_state_stat_diffs(state_stats, reference_stats, prefered_unit: 'km')

    assert_equal 'text-success', diffs['distance'][:css_class]
    assert diffs['distance'][:formatted].start_with?('−')
    assert_equal 'text-success', diffs['stops'][:css_class]
    assert diffs['stops'][:formatted].start_with?('+')
  end

  test 'planning_state_stat_diffs marks higher metrics as danger except active stops' do
    state_stats = { 'distance_total' => 15_000.0, 'stops_size_active' => 4 }
    reference_stats = { 'distance_total' => 12_000.0, 'stops_size_active' => 7 }

    diffs = planning_state_stat_diffs(state_stats, reference_stats, prefered_unit: 'km')

    assert_equal 'text-danger', diffs['distance'][:css_class]
    assert diffs['distance'][:formatted].start_with?('+')
    assert_equal 'text-danger', diffs['stops'][:css_class]
    assert diffs['stops'][:formatted].start_with?('−')
  end

  test 'planning_state_statistics_html renders diff markup when reference differs' do
    statistics = {
      'distance_total' => 10_000.0,
      'stops_size' => 10,
      'stops_size_active' => 8,
      'routes_cost' => 42.5
    }
    reference_statistics = {
      'distance_total' => 12_000.0,
      'stops_size' => 10,
      'stops_size_active' => 6,
      'routes_cost' => 50.0
    }

    html = planning_state_statistics_html(
      statistics,
      prefered_unit: 'km',
      reference_statistics: reference_statistics
    )

    assert_includes html, 'stat-diff'
    assert_includes html, 'text-success'
  end

  test 'planning_state_header_block_order excludes speed and quantities' do
    order = planning_state_header_block_order

    assert_not_includes order, 'speed'
    assert_not_includes order, 'quantities'
  end
end
