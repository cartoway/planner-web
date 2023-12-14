class SimplifyRoutePolylines < ActiveRecord::Migration
  def up
    Route.find_each{ |route|
      route.geojson_tracks&.map!{ |feature|
        next feature unless feature.include?('polylines')

        feature = JSON.parse(feature)
        SimplifyGeometry.polylines(feature)
        feature.to_json
      }
      route.save!(validate: true)
    }
  end
end
