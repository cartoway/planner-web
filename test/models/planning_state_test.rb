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

class PlanningStateTest < ActiveSupport::TestCase
  test 'category_for maps triggers to categories' do
    assert_equal 'mass', PlanningState.category_for('optimize')
    assert_equal 'mass', PlanningState.category_for('vehicle_usage_set')
    assert_equal 'mass', PlanningState.category_for('import')
    assert_equal 'mass', PlanningState.category_for('duplicate')
    assert_equal 'mass', PlanningState.category_for('activate_stops')
    assert_equal 'group', PlanningState.category_for('optimize_route')
    assert_equal 'group', PlanningState.category_for('reverse_order')
    assert_equal 'group', PlanningState.category_for('automatic_insert')
    assert_equal 'individual', PlanningState.category_for('move')
    assert_equal 'individual', PlanningState.category_for('split_by_zones')
    assert_equal 'individual', PlanningState.category_for('vehicle_usage_add')
    assert_equal 'individual', PlanningState.category_for('unknown_trigger')
  end

  test 'prune_excess keeps only the 10 most recent states globally' do
    planning = plannings(:planning_one)
    planning.planning_states.delete_all
    payload = { 'vehicle_usage_set_id' => planning.vehicle_usage_set_id, 'routes' => [] }

    8.times do |i|
      planning.planning_states.create!(
        captured_at: i.seconds.ago,
        trigger: 'optimize',
        category: 'mass',
        payload: payload,
        statistics: { 'routes_cost' => i }
      )
    end

    5.times do |i|
      planning.planning_states.create!(
        captured_at: (10 + i).seconds.ago,
        trigger: 'move',
        category: 'individual',
        payload: payload,
        statistics: { 'routes_cost' => 100 + i }
      )
    end

    PlanningState.prune_excess!(planning.id)

    assert_equal 10, planning.planning_states.count
    assert planning.planning_states.all? { |state| state.statistics['routes_cost'].to_i <= 104 }
  end

  test 'prune_excess keeps pinned states and fills remaining slots with recent unpinned' do
    planning = plannings(:planning_one)
    planning.planning_states.delete_all
    payload = { 'vehicle_usage_set_id' => planning.vehicle_usage_set_id, 'routes' => [] }

    pinned_states = 3.times.map do |i|
      planning.planning_states.create!(
        captured_at: (30 + i).seconds.ago,
        trigger: 'optimize',
        category: 'mass',
        payload: payload,
        statistics: { 'routes_cost' => 100 + i },
        pinned: true
      )
    end

    10.times do |i|
      planning.planning_states.create!(
        captured_at: i.seconds.ago,
        trigger: 'optimize',
        category: 'mass',
        payload: payload,
        statistics: { 'routes_cost' => i }
      )
    end

    PlanningState.prune_excess!(planning.id)

    states = planning.planning_states.reload
    assert_equal 10, states.count
    assert pinned_states.all? { |state| states.exists?(id: state.id) }
    assert_equal 7, states.where(pinned: false).count
    assert states.where(pinned: false).all? { |state| state.statistics['routes_cost'].to_i <= 6 }
  end

  test 'visits_mismatch detects divergent visit ids' do
    planning = plannings(:planning_one)
    state = planning.planning_states.create!(
      captured_at: Time.current,
      trigger: 'move',
      category: 'individual',
      payload: {
        'vehicle_usage_set_id' => planning.vehicle_usage_set_id,
        'routes' => [{
          'route_id' => 1,
          'vehicle_usage_id' => 1,
          'stops' => [
            { 'type' => 'visit', 'visit_id' => 1, 'active' => true, 'index' => 0 },
            { 'type' => 'visit', 'visit_id' => 2, 'active' => true, 'index' => 1 }
          ]
        }]
      },
      statistics: { 'routes_cost' => 0 }
    )

    refute state.visits_mismatch?([1, 2])
    assert state.visits_mismatch?([1])
    assert state.visits_mismatch?([1, 2, 3])
  end

  test 'visits_mismatch ignores stop id changes when visit ids are unchanged' do
    planning = plannings(:planning_one)
    state = planning.planning_states.create!(
      captured_at: Time.current,
      trigger: 'move',
      category: 'individual',
      payload: {
        'vehicle_usage_set_id' => planning.vehicle_usage_set_id,
        'routes' => [{
          'route_id' => 1,
          'vehicle_usage_id' => 1,
          'stops' => [
            { 'type' => 'visit', 'visit_id' => 1, 'active' => true, 'index' => 0 }
          ]
        }]
      },
      statistics: { 'routes_cost' => 0 }
    )

    refute state.visits_mismatch?([1])
  end

  test 'purge_stale deletes states older than retention period' do
    planning = plannings(:planning_one)
    planning.planning_states.delete_all
    payload = { 'vehicle_usage_set_id' => planning.vehicle_usage_set_id, 'routes' => [] }

    recent = planning.planning_states.create!(
      captured_at: 1.week.ago,
      trigger: 'move',
      category: 'individual',
      payload: payload,
      statistics: { 'routes_cost' => 1 }
    )
    stale = planning.planning_states.create!(
      captured_at: 13.weeks.ago,
      trigger: 'move',
      category: 'individual',
      payload: payload,
      statistics: { 'routes_cost' => 2 }
    )

    assert_equal 1, PlanningState.purge_stale!(retention_weeks: 12)

    assert planning.planning_states.exists?(id: recent.id)
    refute PlanningState.unscoped.exists?(id: stale.id)
  end
end
