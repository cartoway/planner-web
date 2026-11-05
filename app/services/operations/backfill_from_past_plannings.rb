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
      operation = PublishFromPlanning.call(planning: planning, date: planning.date, allow_past: true)
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
                AND EXISTS (
                  SELECT 1
                  FROM active_storage_attachments
                  WHERE active_storage_attachments.record_type = 'Stop'
                    AND active_storage_attachments.record_id = stops.id
                    AND active_storage_attachments.name IN ('photos', 'signature')
                )
            )
          )
      SQL
    end

    def copy_route_cursor(operation)
      # Transmit/depot cursors live on operation_routes. Still copy route custom_attributes.
      execute <<~SQL
        UPDATE operation_routes
        SET custom_attributes = CASE
              WHEN routes.custom_attributes = '{}'::jsonb THEN operation_routes.custom_attributes
              ELSE routes.custom_attributes
            END,
            updated_at = now()
        FROM routes
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
