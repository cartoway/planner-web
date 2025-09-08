SimplifyGeojsonTracksJobStruct ||= Job.new(:customer_id, :route_id)
class SimplifyGeojsonTracksJob < SimplifyGeojsonTracksJobStruct
  def perform
    # Accessing Route directly through a Route.find seems to use an obsolete context
    # which prevents to find routes, finding them through the customer plannings makes
    # us able to find them
    route = Route.unscoped.joins(:planning).where(plannings: { customer_id: customer_id }).find_by(id: route_id)
    return if route.nil? || route.geojson_tracks.blank?

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

    # Use update_column to avoid triggering callbacks and version updates
    # This ensures concurrent modifications to the route don't conflict
    # and doesn't touch the associated planning
    route.update_column(:geojson_tracks, simplified_tracks)
  end
end
