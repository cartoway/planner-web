# frozen_string_literal: true

class AddOperationExecutionWriteGuard < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      CREATE OR REPLACE FUNCTION public.operation_execution_write_allowed(
        op_id integer,
        occurred_at timestamp without time zone
      ) RETURNS boolean
      LANGUAGE plpgsql
      STABLE
      AS $$
      DECLARE
        op_status character varying;
        op_closed_at timestamp without time zone;
      BEGIN
        SELECT status, closed_at INTO op_status, op_closed_at
        FROM operations
        WHERE id = op_id;

        IF NOT FOUND THEN
          RETURN false;
        END IF;

        IF op_status = 'in_progress' THEN
          RETURN true;
        END IF;

        IF op_closed_at IS NULL THEN
          RETURN false;
        END IF;

        RETURN COALESCE(occurred_at, clock_timestamp()::timestamp) <= (op_closed_at + INTERVAL '12 hours');
      END;
      $$;

      CREATE OR REPLACE FUNCTION public.enforce_operation_stop_status_event_write() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        op_id integer;
      BEGIN
        SELECT operation_routes.operation_id INTO op_id
        FROM operation_stops
        INNER JOIN operation_routes ON operation_routes.id = operation_stops.operation_route_id
        WHERE operation_stops.id = NEW.operation_stop_id;

        IF NOT public.operation_execution_write_allowed(op_id, NEW.recorded_at) THEN
          RAISE EXCEPTION 'operation_closed'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER operation_stop_status_events_execution_guard
      BEFORE INSERT ON public.operation_stop_status_events
      FOR EACH ROW
      EXECUTE PROCEDURE public.enforce_operation_stop_status_event_write();

      CREATE OR REPLACE FUNCTION public.enforce_operation_stop_execution_write() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        op_id integer;
        occurred_at timestamp without time zone;
      BEGIN
        IF NEW.status IS NOT DISTINCT FROM OLD.status
           AND NEW.eta IS NOT DISTINCT FROM OLD.eta
           AND NEW.status_updated_at IS NOT DISTINCT FROM OLD.status_updated_at
           AND NEW.custom_attributes IS NOT DISTINCT FROM OLD.custom_attributes
           AND NEW.actual_quantities IS NOT DISTINCT FROM OLD.actual_quantities THEN
          RETURN NEW;
        END IF;

        SELECT operation_id INTO op_id
        FROM operation_routes
        WHERE id = NEW.operation_route_id;

        occurred_at := COALESCE(NEW.status_updated_at, clock_timestamp()::timestamp);

        IF NOT public.operation_execution_write_allowed(op_id, occurred_at) THEN
          RAISE EXCEPTION 'operation_closed'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER operation_stops_execution_guard
      BEFORE UPDATE ON public.operation_stops
      FOR EACH ROW
      EXECUTE PROCEDURE public.enforce_operation_stop_execution_write();

      CREATE OR REPLACE FUNCTION public.enforce_operation_route_execution_write() RETURNS trigger
      LANGUAGE plpgsql
      AS $$
      DECLARE
        occurred_at timestamp without time zone;
      BEGIN
        IF NEW.departure_status IS NOT DISTINCT FROM OLD.departure_status
           AND NEW.departure_eta IS NOT DISTINCT FROM OLD.departure_eta
           AND NEW.departure_status_updated_at IS NOT DISTINCT FROM OLD.departure_status_updated_at
           AND NEW.arrival_status IS NOT DISTINCT FROM OLD.arrival_status
           AND NEW.arrival_eta IS NOT DISTINCT FROM OLD.arrival_eta
           AND NEW.arrival_status_updated_at IS NOT DISTINCT FROM OLD.arrival_status_updated_at THEN
          RETURN NEW;
        END IF;

        occurred_at := COALESCE(
          NEW.departure_status_updated_at,
          NEW.arrival_status_updated_at,
          clock_timestamp()::timestamp
        );

        -- Prefer the timestamp of the leg that actually changed.
        IF NEW.departure_status IS DISTINCT FROM OLD.departure_status
           OR NEW.departure_eta IS DISTINCT FROM OLD.departure_eta
           OR NEW.departure_status_updated_at IS DISTINCT FROM OLD.departure_status_updated_at THEN
          occurred_at := COALESCE(NEW.departure_status_updated_at, occurred_at);
        ELSIF NEW.arrival_status IS DISTINCT FROM OLD.arrival_status
              OR NEW.arrival_eta IS DISTINCT FROM OLD.arrival_eta
              OR NEW.arrival_status_updated_at IS DISTINCT FROM OLD.arrival_status_updated_at THEN
          occurred_at := COALESCE(NEW.arrival_status_updated_at, occurred_at);
        END IF;

        IF NOT public.operation_execution_write_allowed(NEW.operation_id, occurred_at) THEN
          RAISE EXCEPTION 'operation_closed'
            USING ERRCODE = 'check_violation';
        END IF;

        RETURN NEW;
      END;
      $$;

      CREATE TRIGGER operation_routes_execution_guard
      BEFORE UPDATE ON public.operation_routes
      FOR EACH ROW
      EXECUTE PROCEDURE public.enforce_operation_route_execution_write();
    SQL
  end

  def down
    execute <<~SQL
      DROP TRIGGER IF EXISTS operation_routes_execution_guard ON public.operation_routes;
      DROP TRIGGER IF EXISTS operation_stops_execution_guard ON public.operation_stops;
      DROP TRIGGER IF EXISTS operation_stop_status_events_execution_guard ON public.operation_stop_status_events;
      DROP FUNCTION IF EXISTS public.enforce_operation_route_execution_write();
      DROP FUNCTION IF EXISTS public.enforce_operation_stop_execution_write();
      DROP FUNCTION IF EXISTS public.enforce_operation_stop_status_event_write();
      DROP FUNCTION IF EXISTS public.operation_execution_write_allowed(integer, timestamp without time zone);
    SQL
  end
end
