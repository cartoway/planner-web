require 'simplify_rb'

class SimplifyGeometry
  def self.polylines(feature, options = { precision: 1e-6 })
    if feature['geometry'] && feature['geometry']['polylines']
      simplified_polyline = process(feature, options).map{ |crd| crd.reverse }
      feature['geometry']['polylines'] = FastPolylines.encode(simplified_polyline, 6)
    end
  end

  def self.polylines_to_coordinates(feature, options = { precision: 1e-6 })
    if feature['geometry'] && feature['geometry']['polylines']
      simplified_polyline = process(feature, options)
      feature['geometry']['coordinates'] = simplified_polyline.map{ |crd| crd }
    end
  end

  private

  def self.process(feature, options = { precision: 1e-6 })
    decoded_polyline = FastPolylines.decode(feature['geometry'].delete('polylines'), 6)
    simplified_polyline = SimplifyRb::Simplifier.new.process(
      decoded_polyline.map{ |a, b| {x: b, y: a} },
      options[:precision],
      false
    )
    simplified_polyline.map{ |crd| crd.values.map{ |a| a.round(6) } }
  end
end
