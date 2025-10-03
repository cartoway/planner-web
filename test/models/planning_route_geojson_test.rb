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

class PlanningRouteGeojsonTest < ActiveSupport::TestCase
  def setup
    @customer = customers(:customer_one)
    @planning = plannings(:planning_one)
    @route = routes(:route_one_one)
    super
  end

  test "should delete route_geojson when planning is destroyed (with delete_all)" do
    # Create route_geojson for the route
    @route.geojson_tracks = ['{"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}']
    route_geojson_id = @route.route_geojson.id

    # Destroy the planning (should delete routes and their route_geojsons via before_destroy callback)
    @planning.destroy

    # Verify route_geojson was deleted
    assert_raises(ActiveRecord::RecordNotFound) do
      RouteGeojson.find(route_geojson_id)
    end

    # Verify route was also deleted
    assert_raises(ActiveRecord::RecordNotFound) do
      Route.find(@route.id)
    end
  end

  test "should destroy route_geojson when planning routes are destroyed" do
    # Create route_geojson for the route
    @route.geojson_tracks = ['{"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}']
    route_geojson_id = @route.route_geojson.id

    # Call default_empty_routes which should destroy all routes and their route_geojsons
    @planning.default_empty_routes

    # Verify route_geojson was destroyed
    assert_raises(ActiveRecord::RecordNotFound) do
      RouteGeojson.find(route_geojson_id)
    end

    # Verify new routes were created
    assert @planning.routes.any?
  end

  test "should destroy route_geojson when individual route is destroyed" do
    # Create route_geojson for the route
    @route.geojson_tracks = ['{"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}']
    route_geojson_id = @route.route_geojson.id

    # Destroy the route
    @route.destroy

    # Verify route_geojson was destroyed
    assert_raises(ActiveRecord::RecordNotFound) do
      RouteGeojson.find(route_geojson_id)
    end
  end
end
