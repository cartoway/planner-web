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

  test 'prune_excess keeps only the 5 most recent states per category' do
    planning = plannings(:planning_one)
    planning.planning_states.delete_all
    payload = { 'vehicle_usage_set_id' => planning.vehicle_usage_set_id, 'routes' => [] }

    6.times do |i|
      planning.planning_states.create!(
        captured_at: i.seconds.ago,
        trigger: 'optimize',
        category: 'mass',
        payload: payload,
        statistics: { 'routes_cost' => i }
      )
    end

    3.times do |i|
      planning.planning_states.create!(
        captured_at: (10 + i).seconds.ago,
        trigger: 'move',
        category: 'individual',
        payload: payload,
        statistics: { 'routes_cost' => 100 + i }
      )
    end

    PlanningState.prune_excess!(planning.id)

    assert_equal 5, planning.planning_states.where(category: 'mass').count
    assert_equal 3, planning.planning_states.where(category: 'individual').count
    assert planning.planning_states.where(category: 'mass').all? { |state| state.statistics['routes_cost'].to_i <= 4 }
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

    6.times do |i|
      planning.planning_states.create!(
        captured_at: i.seconds.ago,
        trigger: 'optimize',
        category: 'mass',
        payload: payload,
        statistics: { 'routes_cost' => i }
      )
    end

    PlanningState.prune_excess!(planning.id)

    mass_states = planning.planning_states.where(category: 'mass')
    assert_equal 5, mass_states.count
    assert pinned_states.all? { |state| mass_states.exists?(id: state.id) }
    assert_equal 2, mass_states.where(pinned: false).count
    assert mass_states.where(pinned: false).all? { |state| state.statistics['routes_cost'].to_i <= 1 }
  end
end
