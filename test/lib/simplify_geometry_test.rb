require 'test_helper'

class SimplifyGeometryTest < ActiveSupport::TestCase
  test 'should handle multipolygon to polygons conversion' do
    zoning = zonings(:zoning_one)
    initial_zone_size = zoning.zones.size
    zone = Zone.new(zoning_id: zoning.id)
    zone.polygon = {
      'type': 'Feature',
      'geometry': {
        'type' => 'MultiPolygon',
        'coordinates' => [
          [
            [
              [0, 0],
              [1, 1],
              [0, 2],
              [0, 0]
            ]
          ],
          [
            [
              [3, 3],
              [4, 4],
              [3, 5],
              [3, 3]
            ]
          ]
        ]
      }
    }.to_json
    zoning.zones << zone

    SimplifyGeometry.dump_multipolygons(zoning)
    assert_equal initial_zone_size + 2, zoning.zones.size
    assert zoning.zones.all?{ |zone| JSON.parse(zone.polygon)['geometry']['type'] == 'Polygon' }
  end

  # focus
  test 'should handle geometry collection' do
    zoning = zonings(:zoning_one)
    initial_zone_size = zoning.zones.size
    zone = Zone.new(zoning_id: zoning.id)
    zone.polygon = {
      'type': 'Feature',
      'geometry': {
        'type' => 'GeometryCollection',
        'geometries' => [
          {
            'type' => 'Polygon',
            'coordinates' => [
              [
                [0, 0],
                [1, 1],
                [0, 2],
                [0, 0]
              ]
            ]
          },
          {
            'type' => 'Polygon',
            'coordinates' => [
              [
                [3, 3],
                [4, 4],
                [3, 5],
                [3, 3]
              ]
            ]
          }
        ]
      }
    }.to_json
    zoning.zones << zone

    SimplifyGeometry.dump_multipolygons(zoning)
    assert_equal initial_zone_size + 2, zoning.zones.size
    assert zoning.zones.all?{ |zone| JSON.parse(zone.polygon)['geometry']['type'] == 'Polygon' }
  end

  test 'should handle invalid geometry types' do
    zoning = zonings(:zoning_one)
    initial_zone_size = zoning.zones.size
    zone = Zone.new(zoning_id: zoning.id)
    zone.polygon = {
      'type': 'Feature',
      'geometry': {
        'type' => 'LineString',
        'coordinates' => [
          [
            [0, 0],
            [1, 1],
            [2, 2],
            [0, 0]
          ]
        ]
      }
    }.to_json
    zoning.zones << zone

    SimplifyGeometry.dump_multipolygons(zoning)
    assert_equal initial_zone_size, zoning.zones.size
    assert zoning.zones.none?{ |zone| JSON.parse(zone.polygon)['geometry']['type'] == 'LineString' }
  end

  test 'should handle collection with invalid geometry types' do
    zoning = zonings(:zoning_one)
    initial_zone_size = zoning.zones.size
    zone = Zone.new(zoning_id: zoning.id)
    zone.polygon = {
      'type': 'Feature',
      'geometry': {
        'type' => 'GeometryCollection',
        'geometries' => [
          {
            'type' => 'Polygon',
            'coordinates' => [
              [
                [0, 0],
                [1, 1],
                [0, 2],
                [0, 0]
              ]
            ]
          },
          {
            'type' => 'LineString',
            'coordinates' => [
              [3, 3],
              [4, 4],
              [3, 5],
              [3, 3]
            ]
          }
        ]
      }
    }.to_json
    zoning.zones << zone

    SimplifyGeometry.dump_multipolygons(zoning)
    assert_equal initial_zone_size + 1, zoning.zones.size
    assert zoning.zones.none?{ |zone| JSON.parse(zone.polygon)['geometry']['type'] == 'LineString' }
    assert zoning.zones.all?{ |zone| JSON.parse(zone.polygon)['geometry']['type'] == 'Polygon' }
  end
end
