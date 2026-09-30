# frozen_string_literal: true

module Operations
  class BackfillFromPastPlannings
    def self.call
      new.call
    end

    def self.revert
      new.revert
    end

    def call
      connection.select_values(candidate_sql).filter_map do |planning_id|
        planning = Planning.find_by(id: planning_id)
        backfill(planning) if planning
      end
    end

    def backfill(planning)
      operation = PublishFromPlanning.call(planning: planning, date: planning.date)
      copy_stop_cursor(operation)
      copy_route_cursor(operation)
      copy_proofs(operation)
      operation.update!(
        status: 'historized',
        published_at: planning.date.in_time_zone,
        closed_at: planning.date.in_time_zone.end_of_day,
        custom_attributes: operation.custom_attributes.merge('_backfill' => true)
      )
      operation
    end

    def revert
      execute <<~SQL
        DELETE FROM active_storage_attachments
        WHERE record_type = 'OperationStop'
          AND name IN ('photos', 'signature')
          AND record_id IN (
            SELECT operation_stops.id
            FROM operation_stops
            JOIN operation_routes ON operation_routes.id = operation_stops.operation_route_id
            JOIN operations ON operations.id = operation_routes.operation_id
            WHERE operations.custom_attributes @> '{"_backfill": true}'::jsonb
          );

        DELETE FROM operations
        WHERE custom_attributes @> '{"_backfill": true}'::jsonb;
      SQL
    end

    private

    def connection
      ActiveRecord::Base.connection
    end

    def execute(sql)
      connection.execute(sql)
    end

    def candidate_sql
      <<~SQL
        SELECT DISTINCT plannings.id
        FROM plannings
        WHERE plannings.date < CURRENT_DATE
          AND NOT EXISTS (
            SELECT 1 FROM operations WHERE operations.planning_id = plannings.id
          )
          AND (
            EXISTS (
              SELECT 1
              FROM routes
              JOIN stops ON stops.route_id = routes.id
              WHERE routes.planning_id = plannings.id
                AND routes.vehicle_usage_id IS NOT NULL
                AND stops.active IS NOT FALSE
                AND (
                  stops.status IS NOT NULL
                  OR stops.eta IS NOT NULL
                  OR stops.status_updated_at IS NOT NULL
                  OR EXISTS (
                    SELECT 1
                    FROM active_storage_attachments
                    WHERE active_storage_attachments.record_type = 'Stop'
                      AND active_storage_attachments.record_id = stops.id
                      AND active_storage_attachments.name IN ('photos', 'signature')
                  )
                )
            )
            OR EXISTS (
              SELECT 1
              FROM routes
              LEFT JOIN route_data AS start_data ON start_data.id = routes.start_route_data_id
              LEFT JOIN route_data AS end_data ON end_data.id = routes.stop_route_data_id
              WHERE routes.planning_id = plannings.id
                AND routes.vehicle_usage_id IS NOT NULL
                AND (
                  start_data.status IS NOT NULL
                  OR end_data.status IS NOT NULL
                  OR routes.arrival_status IS NOT NULL
                  OR routes.last_sent_at IS NOT NULL
                )
            )
          )
      SQL
    end

    def copy_stop_cursor(operation)
      execute <<~SQL
        UPDATE operation_stops
        SET status = stops.status,
            eta = stops.eta,
            status_updated_at = stops.status_updated_at,
            updated_at = now()
        FROM stops
        WHERE operation_stops.stop_id = stops.id
          AND operation_stops.operation_route_id IN (
            SELECT id FROM operation_routes WHERE operation_id = #{operation.id}
          )
          AND (
            stops.status IS NOT NULL
            OR stops.eta IS NOT NULL
            OR stops.status_updated_at IS NOT NULL
          );

        INSERT INTO operation_stop_status_events (
          operation_stop_id, status, eta, recorded_at, source, payload, created_at
        )
        SELECT operation_stops.id,
               operation_stops.status,
               operation_stops.eta,
               COALESCE(operation_stops.status_updated_at, now()),
               'migration',
               '{}'::jsonb,
               now()
        FROM operation_stops
        WHERE operation_stops.status IS NOT NULL
          AND operation_stops.operation_route_id IN (
            SELECT id FROM operation_routes WHERE operation_id = #{operation.id}
          );
      SQL
    end

    def copy_route_cursor(operation)
      execute <<~SQL
        UPDATE operation_routes
        SET departure_status = start_data.status,
            departure_eta = CASE
              WHEN start_data.eta IS NULL THEN NULL
              ELSE operations.date + start_data.eta
            END,
            arrival_status = COALESCE(end_data.status, routes.arrival_status),
            arrival_eta = CASE
              WHEN end_data.eta IS NOT NULL THEN operations.date + end_data.eta
              WHEN routes.arrival_eta IS NOT NULL THEN operations.date + routes.arrival_eta
              ELSE NULL
            END,
            last_sent_at = routes.last_sent_at,
            last_sent_to = routes.last_sent_to,
            custom_attributes = CASE
              WHEN routes.custom_attributes = '{}'::jsonb THEN operation_routes.custom_attributes
              ELSE routes.custom_attributes
            END,
            updated_at = now()
        FROM routes
        LEFT JOIN route_data AS start_data ON start_data.id = routes.start_route_data_id
        LEFT JOIN route_data AS end_data ON end_data.id = routes.stop_route_data_id
        CROSS JOIN operations
        WHERE operations.id = #{operation.id.to_i}
          AND operation_routes.operation_id = operations.id
          AND operation_routes.route_id = routes.id;
      SQL
    end

    # Keep the planning stop attachment. A later version can drop the stop copy.
    def copy_proofs(operation)
      execute <<~SQL
        INSERT INTO active_storage_attachments (name, record_type, record_id, blob_id, created_at)
        SELECT attachment.name, 'OperationStop', operation_stops.id, attachment.blob_id, attachment.created_at
        FROM active_storage_attachments AS attachment
        JOIN operation_stops ON operation_stops.stop_id = attachment.record_id
        WHERE attachment.record_type = 'Stop'
          AND attachment.name IN ('photos', 'signature')
          AND operation_stops.operation_route_id IN (
            SELECT id FROM operation_routes WHERE operation_id = #{operation.id.to_i}
          )
          AND NOT EXISTS (
            SELECT 1
            FROM active_storage_attachments AS existing
            WHERE existing.record_type = 'OperationStop'
              AND existing.record_id = operation_stops.id
              AND existing.name = attachment.name
              AND existing.blob_id = attachment.blob_id
          );
      SQL
    end
  end
end
