require 'test_helper'

class SimplifyGeojsonTracksJobTest < ActiveSupport::TestCase
  setup do
    @route = routes(:route_one_one)
    @geojson_tracks = [
      {
        type: 'Feature',
        geometry: {
          type: 'LineString',
          polylines: '_p~iF~ps|U_ulLnnqC_mqNvxq`@'
        },
        properties: {
          route_id: @route.id,
          color: '#FF0000'
        }
      }.to_json,
      {
        type: 'Feature',
        geometry: {
          type: 'LineString',
          polylines: 'abc123'
        },
        properties: {
          route_id: @route.id,
          color: '#00FF00'
        }
      }.to_json
    ]

    @route.update_column(:geojson_tracks, @geojson_tracks)
  end

  test "should simplify polylines while preserving feature structure" do
    SimplifyGeojsonTracksJob.new(@route.planning.customer_id, @route.id).perform
    @route.reload
    assert_equal 2, @route.geojson_tracks.size

    @route.geojson_tracks.each do |track|
      feature = JSON.parse(track)
      assert_equal 'Feature', feature['type']
      assert_includes feature['geometry'], 'polylines'
      assert_includes feature['properties'], 'route_id'
      assert_includes feature['properties'], 'color'
      assert feature['geometry']['polylines'].is_a?(String)
      assert_not_empty feature['geometry']['polylines']
    end
  end

  test "should handle empty geojson_tracks" do
    @route.update_column(:geojson_tracks, [])
    assert_nothing_raised do
      SimplifyGeojsonTracksJob.new(@route.planning.customer_id, @route.id).perform
    end
  end

  test "should handle single point polylines" do
    single_point_track = [{
      type: 'Feature',
      geometry: {
        type: 'LineString',
        polylines: 'abc'
      },
      properties: {
        route_id: @route.id,
        color: '#0000FF'
      }
    }.to_json]

    @route.update_column(:geojson_tracks, single_point_track)
    SimplifyGeojsonTracksJob.new(@route.planning.customer_id, @route.id).perform
    @route.reload
    feature = JSON.parse(@route.geojson_tracks.first)
    assert_not_empty feature['geometry']['polylines']
  end

  test "should preserve original properties" do
    original_feature = JSON.parse(@geojson_tracks.first)
    SimplifyGeojsonTracksJob.new(@route.planning.customer_id, @route.id).perform
    @route.reload
    simplified_feature = JSON.parse(@route.geojson_tracks.first)
    assert_equal original_feature['properties'], simplified_feature['properties']
  end
end
