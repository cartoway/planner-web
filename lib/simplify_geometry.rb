require 'simplify_rb'

AUTHORIZED_GEOMETRY_TYPES = %w[Polygon MultiPolygon GeometryCollection].freeze

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

  def self.dump_multipolygons(zoning, import = false)
    import &= zoning.zones.any?{ |zone| zone.polygon&.match('MultiPolygon') || zone.polygon&.match('GeometryCollection') }
    new_zones = zoning.zones.flat_map{ |zone|
      geometry = zone.polygon && JSON.parse(zone.polygon)['geometry']
      if geometry
        multipolygon_to_polygons(zone, geometry, import)
      else
        zone.destroy
      end
    }.compact
    Zone.import(new_zones, import) if import && new_zones.any?
    new_zones
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

  def self.multipolygon_to_polygons(zone, feature, destroy = false)
    if feature['type'] == 'MultiPolygon'
      multipolygon_coordinates = feature['coordinates']
      multipolygon_coordinates.map.with_index{ |coords, index|
        new_zone = Zone.new(zone.attributes.merge(
          polygon: { type: 'Feature', 'geometry': { type: 'Polygon', coordinates: coords }}.to_json
        ).except('id'))
        zone.destroy if destroy
        new_zone
      }
    elsif feature['type'] == 'GeometryCollection'
      new_zones = feature['geometries'].flat_map{ |sub_feature|
        multipolygon_to_polygons(zone, sub_feature, destroy) if sub_feature && AUTHORIZED_GEOMETRY_TYPES.include?(sub_feature['type'])
    }.compact
      zone.destroy if zone && destroy
      new_zones
    else
      [zone] unless destroy
    end
  end
end
