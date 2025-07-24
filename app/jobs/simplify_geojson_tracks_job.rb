SimplifyGeojsonTracksJobStruct ||= Job.new(:customer_id, :route_id)
class SimplifyGeojsonTracksJob < SimplifyGeojsonTracksJobStruct
  def perform
    begin
      Route.where(id: route_id).lock('FOR UPDATE NOWAIT').pluck(:id)

      sql = <<~SQL
        UPDATE routes
        SET geojson_tracks = (
          SELECT array_agg(
            (
              to_jsonb(
                jsonb_set(
                  track::jsonb,
                  '{geometry,polylines}',
                  to_jsonb(
                    (
                      SELECT ST_AsEncodedPolyline(
                        ST_SimplifyPreserveTopology(
                          CASE
                            WHEN ST_NPoints(ST_LineFromEncodedPolyline((track::jsonb->'geometry'->>'polylines')::text)) = 1
                            THEN ST_MakeLine(
                              ST_StartPoint(ST_LineFromEncodedPolyline((track::jsonb->'geometry'->>'polylines')::text)),
                              ST_StartPoint(ST_LineFromEncodedPolyline((track::jsonb->'geometry'->>'polylines')::text))
                            )
                            ELSE ST_LineFromEncodedPolyline((track::jsonb->'geometry'->>'polylines')::text)
                          END,
                          0.000001
                        )
                      )
                    )
                  )
                )
              )::text
            )
          )
          FROM unnest(routes.geojson_tracks) AS track
        )
        WHERE id = #{route_id}
          AND geojson_tracks IS NOT NULL
          AND array_length(geojson_tracks, 1) > 0
      SQL

      ActiveRecord::Base.connection.exec_update(sql, "Simplify #{route_id}")
    rescue ActiveRecord::LockWaitTimeout, ActiveRecord::StatementInvalid
      # Simplifying is unnecessary if the route is locked as it is about to change
    end
  end
end
