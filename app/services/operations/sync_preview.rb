# frozen_string_literal: true

module Operations
  # Succinct planning ↔ operation stop membership diff for the sync modal.
  class SyncPreview
    def self.call(planning:, operation:)
      new(planning, operation).call
    end

    def initialize(planning, operation)
      @planning = planning
      @operation = operation
    end

    def call
      active = @operation.operation_routes.active_sync.includes(:operation_stops).index_by(&:route_id)
      @planning.routes.select { |route| route.vehicle_usage_id.present? }.each_with_object({}) do |route, hash|
        op_route = active[route.id]
        planning_keys = keys_for_planning(route)
        operation_keys = op_route ? keys_for_operation(op_route) : []
        added = (planning_keys - operation_keys).size
        removed = (operation_keys - planning_keys).size
        hash[route.id.to_s] = {
          'in_operation' => op_route.present?,
          'dirty' => op_route.nil? || added.positive? || removed.positive? || planning_keys != operation_keys,
          'added' => added,
          'removed' => removed
        }
      end
    end

    private

    def keys_for_planning(route)
      route.stops.reject { |stop| stop.active == false }.sort_by(&:index).map { |stop| planning_key(stop) }
    end

    def keys_for_operation(operation_route)
      operation_route.operation_stops
                     .select { |stop| stop.sync_state == 'active' && stop.active != false }
                     .sort_by(&:index)
                     .map { |stop| operation_key(stop) }
    end

    def planning_key(stop)
      kind = Snapshots.kind_for(stop)
      case kind
      when 'visit' then "v:#{stop.visit_id}"
      when 'store' then "s:#{stop.store_id}:#{stop.store_reload_id}"
      else "r:#{stop.id}"
      end
    end

    def operation_key(stop)
      case stop.kind
      when 'visit' then "v:#{stop.visit_id}"
      when 'store' then "s:#{stop.store_id}:#{stop.store_reload_id}"
      else "r:#{stop.stop_id}"
      end
    end
  end
end
