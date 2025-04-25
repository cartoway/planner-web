require 'simplify_rb'

AUTHORIZED_GEOMETRY_TYPES = %w[Feature Polygon MultiPolygon GeometryCollection].freeze

class SimplifyGeometry
  def self.polygones_to_coordinates(feature, **options)
    if feature['type'] == 'Polygon' && feature['coordinates']
      feature['coordinates'].map!{ |coords|
        process(coords.map{ |a, b| {x: a, y: b} }, **options)
      }
    end
    feature
  end

  def self.polylines(feature, **options)
    options = { geometry: 'polylines', encode_output: true }.merge(options)
    if feature['geometry'] && feature['geometry']['polylines']
      decoded_polyline = decoded_polyline = FastPolylines.decode(feature['geometry'].delete('polylines'), 6)
      # Be aware the simplifier reverses polylines order lat/lng to lng/lat
      coordinates = decoded_polyline.map{ |a, b| {x: b, y: a} }
      simplified_polyline = process(coordinates, **options)
      if options[:encode_output]
        simplified_polyline.map!{ |crd| crd.reverse } # Polylines return to initial order lat/lng
        feature['geometry']['polylines'] = FastPolylines.encode(simplified_polyline, 6)
      else
        feature['geometry']['coordinates'] = simplified_polyline.map{ |crd| crd }
      end
    end
  end

  def self.polylines_to_coordinates(feature, **options)
    polylines(feature, **options.merge!(encode_output: false))
  end

  def self.dump_multipolygons(zoning)
    new_zones = zoning.zones.flat_map{ |zone|
      geometry = zone.polygon && JSON.parse(zone.polygon)['geometry']
      multipolygon_to_polygons(zone, geometry) if geometry
    }.compact

    ids = []
    new_zones.group_by{ |new_zone|
      new_zone.attributes.keys
    }.each_value{ |zone_group|
      result = Zone.import(zone_group, on_duplicate_key_update: { conflict_target: [:id], columns: :all })
      ids += result.ids
    }
    # Remove zones associated with the zoning that are not included in the imported zones
    Zone.where(zoning_id: zoning.id).where.not(id: ids).destroy_all
    zoning.reload

    zoning
  end

  private

  def self.process(coordinates, **options)
    options = { precision: 1e-6 }.merge(options)
    unless options[:skip_simplifier]
      coordinates = SimplifyRb::Simplifier.new.process(
        coordinates,
        options[:precision],
        true
      )
    end
    coordinates.map{ |crd| crd.values.map{ |a| a.round(6) } }
  end

  def self.multipolygon_to_polygons(zone, feature)
    case feature['type']
    when 'MultiPolygon'
      multipolygon_coordinates = feature['coordinates']
      multipolygon_coordinates.map.with_index{ |coords, index|
        new_zone = Zone.new(zone.attributes.merge(
          polygon: { type: 'Feature', 'geometry': { type: 'Polygon', coordinates: coords }}.to_json
        ).except('id'))
        new_zone
      }
    when 'GeometryCollection'
      feature['geometries'].flat_map{ |sub_feature|
        multipolygon_to_polygons(Zone.new(zone.attributes.except('id')), sub_feature) if sub_feature && AUTHORIZED_GEOMETRY_TYPES.include?(sub_feature['type'])
      }.compact
    when 'Polygon'
      zone.polygon = { type: 'Feature', 'geometry': feature }.to_json
      [zone]
    when 'Feature'
      multipolygon_to_polygons(zone, feature['geometry'])
    else
      []
    end
  end
end
