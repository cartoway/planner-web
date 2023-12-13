require 'simplify_rb'

class SimplifyGeometry
  def self.polylines(feature, options = { precision: 1e-6})
    feature = JSON.parse(feature)
    if feature['geometry'] && feature['geometry']['polylines']
      decoded_polyline = Polylines::Decoder.decode_polyline(feature['geometry'].delete('polylines'), 1e6)
      simplified_polyline = SimplifyRb::Simplifier.new.process(
        decoded_polyline.map{ |a, b| {x: b, y: a} },
        options[:precision],
        false
      )
      feature['geometry']['coordinates'] = simplified_polyline.map{ |crd| crd.values.map{ |a| a.round(6) } }
    end
    feature.to_json
  end
end
