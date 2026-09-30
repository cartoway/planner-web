# frozen_string_literal: true

module OperationStops
  # Move a visit stop to another route of the same open operation and log the transfer.
  class Transfer
    Error = Class.new(StandardError)

    def self.call(operation_stop:, target_operation_route:, recorded_at: Time.current, source: 'mobile', actor_ref: nil)
      new(operation_stop, target_operation_route, recorded_at, source, actor_ref).call
    end

    def initialize(operation_stop, target_operation_route, recorded_at, source, actor_ref)
      @operation_stop = operation_stop
      @source_route = operation_stop.operation_route
      @target_route = target_operation_route
      @recorded_at = recorded_at.is_a?(String) ? Time.zone.parse(recorded_at) : recorded_at.in_time_zone
      @source = source.presence || 'mobile'
      @actor_ref = actor_ref
    end

    def call
      validate!
      from_name = route_label(@source_route)
      to_name = route_label(@target_route)

      ActiveRecord::Base.transaction do
        move_operation_stop!
        RecordStatus.call(
          operation_stop: @operation_stop.reload,
          status: 'transferred',
          recorded_at: @recorded_at,
          source: @source,
          actor_ref: @actor_ref,
          payload: {
            'from_operation_route_id' => @source_route.id,
            'from_route_name' => from_name,
            'to_operation_route_id' => @target_route.id,
            'to_route_name' => to_name
          }
        )
      end
      move_planning_stop!
      @operation_stop
    end

    private

    def validate!
      raise Error, 'same route' if @source_route.id == @target_route.id
      raise Error, 'different operation' if @source_route.operation_id != @target_route.operation_id
      raise Error, 'operation closed' unless @source_route.operation.open?
      raise Error, 'target unassigned' if @target_route.unassigned? || @target_route.route_id.blank?
      raise Error, 'source unassigned' if @source_route.unassigned? || @source_route.route_id.blank?
      raise Error, 'not a visit' unless @operation_stop.kind == 'visit'
    end

    def route_label(operation_route)
      operation_route.vehicle_name.presence || operation_route.ref.presence || "##{operation_route.id}"
    end

    def move_operation_stop!
      next_index = (@target_route.operation_stops.maximum(:index) || 0) + 1
      @operation_stop.update!(operation_route_id: @target_route.id, index: next_index)
    end

    # Keep planning membership in sync without a full router compute (routes stay outdated).
    def move_planning_stop!
      return if @operation_stop.stop_id.blank? || @target_route.route_id.blank?

      stop = Stop.find_by(id: @operation_stop.stop_id)
      return unless stop

      source_route_id = stop.route_id
      next_index = (Stop.where(route_id: @target_route.route_id).maximum(:index) || 0) + 1
      stop.update_columns(route_id: @target_route.route_id, index: next_index, updated_at: Time.current)
      Route.where(id: [source_route_id, @target_route.route_id].compact).update_all(outdated: true, updated_at: Time.current)
    end
  end
end
