# frozen_string_literal: true

module Operations
  class SyncFromPlanning
    CURSOR_STOP = %w[status eta status_updated_at].freeze
    # last_sent_* belong to operation transmit (email/SMS), not planning device send — do not sync from Route.
    CURSOR_ROUTE = %w[
      departure_status departure_eta departure_status_updated_at
      arrival_status arrival_eta arrival_status_updated_at
    ].freeze

    def self.call(planning:, operation:, route_ids: nil, stop_ids: nil, refresh_snapshots: true, desync_route_ids: nil, update_selection_meta: false)
      new(planning, operation, route_ids, stop_ids, refresh_snapshots, desync_route_ids, update_selection_meta).call
    end

    def initialize(planning, operation, route_ids, stop_ids, refresh_snapshots, desync_route_ids, update_selection_meta)
      @planning = planning
      @operation = operation
      @route_ids = route_ids&.map(&:to_i)
      @stop_ids = stop_ids&.map(&:to_i)
      @refresh_snapshots = refresh_snapshots
      @desync_route_ids = Array(desync_route_ids).map(&:to_i)
      @update_selection_meta = update_selection_meta
    end

    def call
      raise ArgumentError, 'operation is not linked to this planning' if @operation.planning_id != @planning.id
      raise EmptyRoutes if @route_ids&.empty? && @desync_route_ids.empty?

      Operation.transaction do
        @units_by_id = @planning.customer.deliverable_units.index_by(&:id)
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
        membership_before = current_membership_route_ids

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

        # Within the sync scope, anything no longer on the planning is removed (no orphan zombies).
        remove_missing!
        remove_desync_routes!
        attrs = {
          synced_at: Time.current,
          planning_snapshot: Snapshots.planning(@planning)
        }
        if update_selection_meta?
          membership = membership_route_ids_after(membership_before)
          attrs[:structure_fingerprint] = Snapshots.fingerprint(@planning, visible_routes_only: false, route_ids: membership)
          attrs[:custom_attributes] = @operation.custom_attributes.merge('_route_ids' => membership)
        elsif full_sync?
          attrs[:structure_fingerprint] = Snapshots.fingerprint(@planning, visible_routes_only: visible_routes_only?, route_ids: scoped_route_ids_for_fingerprint)
        end
        @operation.update!(attrs)
        OperationDeliveryTracking.ensure_for!(@operation)
      end
      @operation
    end

    private

    def full_sync?
      @route_ids.nil? && @stop_ids.nil?
    end

    def update_selection_meta?
      @update_selection_meta && (@route_ids || @desync_route_ids.any?)
    end

    def current_membership_route_ids
      ids = @operation.custom_attributes['_route_ids']
      return ids.map(&:to_i) if ids.present?

      @operation.operation_routes.active_sync.where.not(route_id: nil).pluck(:route_id)
    end

    def membership_route_ids_after(before)
      ((before - @desync_route_ids) | Array(@route_ids)).uniq
    end

    def visible_routes_only?
      @operation.custom_attributes['_visible_routes_only'] == true
    end

    def scoped_route_ids_for_fingerprint
      ids = @operation.custom_attributes['_route_ids']
      ids.presence
    end

    def scoped_planning_routes
      # Same graph as PublishFromPlanning#routes_for (destinations + vehicle snapshots).
      routes = @planning.routes.includes([:route_geojson] + Planning::ROUTE_DETAILS_ROUTE_PRELOAD).to_a
      routes = routes.reject { |route| route.vehicle_usage_id.nil? }
      routes = routes.reject(&:hidden) if visible_routes_only?
      return routes unless @route_ids

      routes.select { |route| @route_ids.include?(route.id) }
    end

    def scoped_stops(route)
      stops = route.stops.select(&:active?)
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
      PublishFromPlanning.new(@planning, false).send(:build_route, @operation, route, next_index, @units_by_id, with_stops: false)
    end

    def create_stop(operation_route, stop)
      PublishFromPlanning.new(@planning, false).send(:build_stop, operation_route, stop, @units_by_id)
    end

    def next_index
      (@operation.operation_routes.maximum(:index) || -1) + 1
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
      store = Snapshots.store_for(stop)
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

    def remove_missing!
      scope_route_ids = if @route_ids
                          @operation.operation_routes.where(route_id: @route_ids).pluck(:id)
                        else
                          @operation.operation_routes.pluck(:id)
                        end
      (@operation.operation_routes.where(id: scope_route_ids).pluck(:id) - @matched_route_ids).each do |id|
        OperationRoute.find(id).destroy!
      end

      stop_scope = OperationStop.where(operation_route_id: @scoped_operation_route_ids + scope_route_ids)
      stop_scope = stop_scope.where(stop_id: @stop_ids) if @stop_ids
      stop_scope.where.not(id: @matched_stop_ids).find_each(&:destroy!)
    end

    # Explicit desync from the sync modal: drop the route (and stops/proofs) from the operation.
    def remove_desync_routes!
      return if @desync_route_ids.empty?

      @operation.operation_routes.where(route_id: @desync_route_ids).find_each(&:destroy!)
    end
  end
end
