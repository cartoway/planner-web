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

class RouteGeojsonTest < ActiveSupport::TestCase
  def setup
    @customer = customers(:customer_one)
    @planning = plannings(:planning_one)
    @route = routes(:route_one_one)
    super
  end

  test "should set geojson_tracks through delegation" do
    test_tracks = ['{"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}']

    @route.geojson_tracks = test_tracks
    assert_equal test_tracks, @route.geojson_tracks
    assert_equal test_tracks, @route.route_geojson.tracks
  end

  test "should set geojson_points through delegation" do
    test_points = ['{"type":"Feature","geometry":{"type":"Point","coordinates":[0,0]}}']

    @route.geojson_points = test_points
    assert_equal test_points, @route.geojson_points
    assert_equal test_points, @route.route_geojson.points
  end

  test "should maintain backward compatibility with existing API" do
    # Test that the existing methods still work
    test_tracks = ['{"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}']
    test_points = ['{"type":"Feature","geometry":{"type":"Point","coordinates":[0,0]}}']

    @route.geojson_tracks = test_tracks
    @route.geojson_points = test_points

    # Verify the data is stored correctly
    assert_equal test_tracks, @route.geojson_tracks
    assert_equal test_points, @route.geojson_points

    # Verify the route_geojson record exists and has the correct data
    assert_not_nil @route.route_geojson
    assert_equal test_tracks, @route.route_geojson.tracks
    assert_equal test_points, @route.route_geojson.points
  end

  test "should destroy route_geojson when route is destroyed" do
    @route.geojson_tracks = ['test']
    route_geojson_id = @route.route_geojson.id

    @route.destroy

    assert_raises(ActiveRecord::RecordNotFound) do
      RouteGeojson.find(route_geojson_id)
    end
  end

  test "should handle complete_geojson method correctly" do
    test_tracks = ['{"type":"Feature","geometry":{"type":"LineString","coordinates":[[0,0],[1,1]]}}']
    test_points = ['{"type":"Feature","geometry":{"type":"Point","coordinates":[0,0]}}']

    @route.geojson_tracks = test_tracks
    @route.geojson_points = test_points

    # Call complete_geojson which should add route_id to properties
    @route.complete_geojson

    # Verify route_id was added to tracks
    tracks_with_route_id = @route.geojson_tracks
    assert_equal 1, tracks_with_route_id.length
    track_data = JSON.parse(tracks_with_route_id.first)
    assert_equal @route.id, track_data['properties']['route_id']

    # Verify route_id was added to points
    points_with_route_id = @route.geojson_points
    assert_equal 1, points_with_route_id.length
    point_data = JSON.parse(points_with_route_id.first)
    assert_equal @route.id, point_data['properties']['route_id']
  end

  test "should automatically create route_geojson when route is created" do
    # Create a new route
    new_route = Route.create!(
      planning: @planning,
      vehicle_usage: @route.vehicle_usage,
      outdated: false
    )

    # Verify route_geojson was created automatically
    assert_not_nil new_route.route_geojson
    assert_equal [], new_route.route_geojson.tracks
    assert_equal [], new_route.route_geojson.points
  end
end
