SimplifyGeojsonTracksJobStruct ||= Job.new(:customer_id, :route_id)
class SimplifyGeojsonTracksJob < SimplifyGeojsonTracksJobStruct
  def perform
    route = Route.find(route_id)
    return if route.geojson_tracks.empty?

    simplified_tracks = route.geojson_tracks.map do |geojson_track|
      feature = JSON.parse(geojson_track)
      encoded_polyline = feature['geometry']['polylines']

      sql = "SELECT ST_AsEncodedPolyline(
        ST_SimplifyPreserveTopology(
          CASE
            WHEN ST_NPoints(ST_LineFromEncodedPolyline('#{encoded_polyline}')) = 1
            THEN ST_MakeLine(
              ST_StartPoint(ST_LineFromEncodedPolyline('#{encoded_polyline}')),
              ST_StartPoint(ST_LineFromEncodedPolyline('#{encoded_polyline}'))
            )
            ELSE ST_LineFromEncodedPolyline('#{encoded_polyline}')
          END,
          0.000001
        )
      )"

      result = ActiveRecord::Base.connection.execute(sql).first

      feature['geometry']['polylines'] = result['st_asencodedpolyline']
      feature.to_json
    end

    route.update_column(:geojson_tracks, simplified_tracks)
  end
end
