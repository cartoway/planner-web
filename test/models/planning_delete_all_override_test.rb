# Copyright © Cartoway, 2025
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

class PlanningDeleteAllOverrideTest < ActiveSupport::TestCase
  def setup
    @planning = plannings(:planning_one)
    @route = routes(:route_one_one)
    super
  end

  test "should delete route_geojsons when planning routes are deleted with custom method" do
    # Verify initial state
    assert_equal 1, RouteGeojson.where(route_id: @route.id).count

    # Delete routes using our custom method
    @planning.delete_all_routes

    # Verify route_geojsons are deleted
    assert_equal 0, RouteGeojson.where(route_id: @route.id).count

    # Verify routes are deleted
    assert_equal 0, @planning.routes.count
  end

  test "should handle empty routes association gracefully" do
    # Create a planning with no routes
    empty_planning = Planning.create!(
      customer: customers(:customer_one),
      name: "Empty Planning",
      vehicle_usage_set: customers(:customer_one).vehicle_usage_sets.first
    )

    # This should not raise an error
    assert_nothing_raised do
      empty_planning.delete_all_routes
    end
  end

  test "should work with multiple routes and route_geojsons" do
    # Create additional routes
    route2 = Route.create!(
      planning: @planning,
      vehicle_usage: @planning.customer.vehicle_usage_sets.first.vehicle_usages.first
    )

    route2.route_geojson.update_columns(
      tracks: ['{"type":"Feature","properties":{"color":"#ff922b"},"geometry":{"type":"LineString","coordinates":[[2.3522,48.8566],[2.3523,48.8567]]}}'],
      points: ['{"type":"Feature","properties":{"color":"#ff922b"},"geometry":{"type":"Point","coordinates":[2.3522,48.8566]}}']
    )

    # Verify initial state
    assert_equal 2, RouteGeojson.where(route_id: [@route.id, route2.id]).count

    # Delete all routes using our custom method
    @planning.delete_all_routes

    # Verify all route_geojsons are deleted
    assert_equal 0, RouteGeojson.where(route_id: [@route.id, route2.id]).count

    # Verify all routes are deleted
    assert_equal 0, @planning.routes.count
  end
end
