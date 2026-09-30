# frozen_string_literal: true

module Operations
  class SyncFromPlanning
    CURSOR_STOP = %w[status eta status_updated_at].freeze
    CURSOR_ROUTE = %w[
      departure_status departure_eta departure_status_updated_at
      arrival_status arrival_eta arrival_status_updated_at
      last_sent_at last_sent_to
    ].freeze

    def self.call(planning:, operation:, route_ids: nil, stop_ids: nil, refresh_snapshots: true, orphan_policy: :mark)
      new(planning, operation, route_ids, stop_ids, refresh_snapshots, orphan_policy).call
    end

    def initialize(planning, operation, route_ids, stop_ids, refresh_snapshots, orphan_policy)
      @planning = planning
      @operation = operation
      @route_ids = route_ids&.map(&:to_i)
      @stop_ids = stop_ids&.map(&:to_i)
      @refresh_snapshots = refresh_snapshots
      @orphan_policy = orphan_policy.to_sym
    end

    def call
      raise ArgumentError, 'operation is not linked to this planning' if @operation.planning_id != @planning.id

      Operation.transaction do
        @units_by_id = @planning.customer.deliverable_units.index_by(&:id)
        @date = @operation.date
        @available_route_ids = @operation.operation_routes.map(&:id)
        @available_stop_ids = @operation.operation_stops.map(&:id)
        @routes_by_route_id = index_routes(&:route_id)
        @routes_by_usage_id = index_routes(&:vehicle_usage_id)
        @routes_by_vehicle_id = index_routes(&:vehicle_id)
        @stops_by_stop_id = index_stops(&:stop_id)
        @stops_by_visit_id = index_stops { |stop| stop.visit_id if stop.kind == 'visit' }
        @stops_by_store = index_stops { |stop| [stop.store_id, stop.store_reload_id] if stop.kind == 'store' }
        @matched_route_ids = []
        @matched_stop_ids = []
        @scoped_operation_route_ids = []

        scoped_planning_routes.each do |route|
          operation_route = take_route(route) || create_route(route)
          @matched_route_ids << operation_route.id
          @scoped_operation_route_ids << operation_route.id
          refresh_route(operation_route, route)
          scoped_stops(route).each do |stop|
            operation_stop = take_stop(stop) || create_stop(operation_route, stop)
            @matched_stop_ids << operation_stop.id
            refresh_stop(operation_stop, operation_route, stop)
          end
        end

        orphan_missing! if @orphan_policy == :mark
        @operation.update!(
          synced_at: Time.current,
          structure_fingerprint: full_sync? ? Snapshots.fingerprint(@planning, visible_routes_only: visible_routes_only?, route_ids: scoped_route_ids_for_fingerprint) : @operation.structure_fingerprint,
          planning_snapshot: Snapshots.planning(@planning)
        )
      end
      @operation
    end

    private

    def full_sync?
      @route_ids.nil? && @stop_ids.nil?
    end

    def visible_routes_only?
      @operation.custom_attributes['_visible_routes_only'] == true
    end

    def scoped_route_ids_for_fingerprint
      ids = @operation.custom_attributes['_route_ids']
      ids.presence
    end

    def scoped_planning_routes
      routes = @planning.routes.includes(:vehicle_usage, :route_geojson, :route_data, :start_route_data, :stop_route_data, stops: [:visit, :store, :store_reload]).to_a
      routes = routes.reject { |route| route.vehicle_usage_id.nil? }
      routes = routes.reject(&:hidden) if visible_routes_only?
      return routes unless @route_ids

      routes.select { |route| @route_ids.include?(route.id) }
    end

    def scoped_stops(route)
      stops = route.stops.reject { |stop| stop.active == false }
      return stops unless @stop_ids

      stops.select { |stop| @stop_ids.include?(stop.id) }
    end

    def index_routes
      @operation.operation_routes.each_with_object({}) do |operation_route, hash|
        key = yield(operation_route)
        hash[key] = operation_route if key.present? && !hash.key?(key)
      end
    end

    def index_stops
      @operation.operation_stops.each_with_object({}) do |operation_stop, hash|
        key = yield(operation_stop)
        hash[key] = operation_stop if key.present? && !hash.key?(key)
      end
    end

    def take_route(route)
      vehicle_id = route.vehicle_usage&.vehicle_id
      candidates = [
        @routes_by_route_id[route.id],
        (@routes_by_usage_id[route.vehicle_usage_id] if route.vehicle_usage_id),
        (@routes_by_vehicle_id[vehicle_id] if vehicle_id)
      ]
      candidates.compact.each do |candidate|
        return candidate if @available_route_ids.delete(candidate.id)
      end
      nil
    end

    def take_stop(stop)
      kind = Snapshots.kind_for(stop)
      store_key = [stop.store_id, stop.store_reload_id]
      candidates = [
        @stops_by_stop_id[stop.id],
        (@stops_by_visit_id[stop.visit_id] if kind == 'visit' && stop.visit_id),
        (@stops_by_store[store_key] if kind == 'store')
      ]
      candidates.compact.each do |candidate|
        return candidate if @available_stop_ids.delete(candidate.id)
      end
      nil
    end

    def create_route(route)
      unassigned = route.vehicle_usage_id.nil?
      PublishFromPlanning.new(@planning, false).send(:build_route, @operation, route, next_index(unassigned), unassigned, @date, @units_by_id, copy_cursor: false, with_stops: false)
    end

    def create_stop(operation_route, stop)
      PublishFromPlanning.new(@planning, false).send(:build_stop, operation_route, stop, @units_by_id, copy_cursor: false)
    end

    def next_index(unassigned)
      return nil if unassigned

      (@operation.operation_routes.where(unassigned: false).maximum(:index) || -1) + 1
    end

    def refresh_route(operation_route, route)
      return unless @refresh_snapshots

      vehicle = route.vehicle_usage&.vehicle
      operation_route.update!(
        route: route,
        vehicle_usage: route.vehicle_usage,
        vehicle: vehicle,
        ref: route.ref,
        color: route.color.presence || vehicle&.color,
        hidden: route.hidden || false,
        unassigned: route.vehicle_usage_id.nil?,
        sync_state: 'active',
        vehicle_snapshot: Snapshots.vehicle(vehicle),
        vehicle_usage_snapshot: Snapshots.vehicle_usage(route.vehicle_usage),
        route_snapshot: Snapshots.route(route)
      )
    end

    def refresh_stop(operation_stop, operation_route, stop)
      return unless @refresh_snapshots

      kind = Snapshots.kind_for(stop)
      visit = stop.visit
      destination = visit&.destination
      store = stop.store || stop.store_reload&.store
      operation_stop.update!(
        operation_route: operation_route,
        stop: stop,
        visit: visit,
        destination: destination,
        store: store,
        store_reload: stop.store_reload,
        kind: kind,
        index: stop.index,
        active: stop.active != false,
        locked: stop.locked || false,
        sync_state: 'active',
        destination_snapshot: Snapshots.destination(destination),
        visit_snapshot: kind == 'visit' ? Snapshots.visit(visit, @units_by_id) : {},
        store_snapshot: Snapshots.store(store, stop.store_reload),
        stop_snapshot: Snapshots.stop(stop),
        custom_attributes: stop.custom_attributes || {}
      )
    end

    def orphan_missing!
      scope_route_ids = if @route_ids
                          @operation.operation_routes.where(route_id: @route_ids).pluck(:id)
                        else
                          @operation.operation_routes.pluck(:id)
                        end
      (@operation.operation_routes.where(id: scope_route_ids).pluck(:id) - @matched_route_ids).each do |id|
        mark_orphaned(OperationRoute.find(id))
      end

      stop_scope = OperationStop.where(operation_route_id: @scoped_operation_route_ids + scope_route_ids)
      stop_scope = stop_scope.where(stop_id: @stop_ids) if @stop_ids
      stop_scope.where.not(id: @matched_stop_ids).find_each { |stop| mark_orphaned(stop) }
    end

    def mark_orphaned(record)
      return unless record.sync_state == 'active'

      record.update_columns(sync_state: 'orphaned', updated_at: Time.current)
    end
  end
end
