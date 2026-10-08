# frozen_string_literal: true

module OperationStops
  class RecordStatus
    def self.call(operation_stop:, status:, recorded_at:, eta: nil, source: 'mobile', source_ref: nil, actor_ref: nil, payload: {})
      new(operation_stop, status, recorded_at, eta, source, source_ref, actor_ref, payload).call
    end

    def initialize(operation_stop, status, recorded_at, eta, source, source_ref, actor_ref, payload)
      @operation_stop = operation_stop
      @status = status.presence
      @recorded_at = recorded_at.is_a?(String) ? Time.zone.parse(recorded_at) : recorded_at.in_time_zone
      @eta = eta
      @source = source.presence || 'mobile'
      @source_ref = source_ref
      @actor_ref = actor_ref
      @payload = payload || {}
    end

    def call
      raise ArgumentError, 'transferred status cannot be reset' if clearing_transferred?

      event = @operation_stop.operation_stop_status_events.create!(
        status: @status,
        eta: @eta,
        recorded_at: @recorded_at,
        source: @source,
        source_ref: @source_ref,
        actor_ref: @actor_ref,
        payload: @payload
      )
      cursor_updated = project_cursor
      @operation_stop.reload
      broadcast_stop_patch if cursor_updated
      { event: event, cursor_updated: cursor_updated, operation_stop: @operation_stop }
    end

    private

    def clearing_transferred?
      @operation_stop.status.to_s.downcase == 'transferred' && @status.blank?
    end

    def broadcast_stop_patch
      route = @operation_stop.operation_route
      operation = route&.operation
      return unless operation

      Turbo::StreamsChannel.broadcast_stream_to(
        operation,
        content: %(<turbo-stream action="refresh_stop" target="map"><template>#{ERB::Util.html_escape(stop_patch_payload(route).to_json)}</template></turbo-stream>)
      )
      unless @source == 'demo'
        OperationDeliveryTracking.where(operation_id: operation.id).find_each do |tracking|
          Turbo::StreamsChannel.broadcast_refresh_to(tracking.turbo_stream_name)
        end
      end
    rescue StandardError => e
      Rails.logger.warn("operation turbo refresh failed: #{e.class}: #{e.message}")
    end

    def stop_patch_payload(route)
      board = route.board
      stop = @operation_stop
      delay = stop.delay_minutes
      {
        stop_id: stop.id,
        route_id: route.id,
        phase: stop.phase,
        status: stop.status,
        kind: stop.kind,
        index: stop.index,
        planned_arrival_clock: stop.planned_arrival_clock,
        actual_arrival_clock: stop.actual_arrival_clock,
        planned_departure_clock: stop.planned_departure_clock,
        actual_departure_clock: stop.actual_departure_clock,
        delay: delay,
        aside: stop_aside(stop, delay),
        started: route.started?,
        route: {
          delivered: board[:delivered],
          failed: board[:failed],
          exception: board[:exception],
          late: board[:late],
          upcoming: board[:upcoming],
          current: board[:current],
          total: board[:total],
          delay: board[:delay]
        }
      }
    end

    def stop_aside(stop, delay)
      phase = stop.phase
      if phase == 'failed'
        { css: 'operation-gap is-bad', kind: 'status' }
      elsif phase == 'exception'
        { css: 'operation-gap is-exception', kind: 'exception' }
      elsif phase == 'started'
        { css: 'badge operation-now', kind: 'status' }
      elsif phase == 'current'
        { css: 'badge operation-now', kind: 'en_route' }
      elsif (stop.kind == 'store' && stop.treated?) || (phase == 'delivered' && delay&.negative?)
        { css: 'operation-gap is-ok', kind: 'status' }
      elsif delay && delay > OperationStop::LATE_AFTER_MINUTES
        { css: 'operation-gap is-late', kind: 'late' }
      elsif delay
        { css: 'operation-gap is-ok', kind: 'delay' }
      elsif phase == 'late'
        { css: 'operation-gap is-late', kind: 'late_risk' }
      end
    end

    # rubocop:disable Naming/PredicateMethod
    def project_cursor
      current = @operation_stop.status_updated_at
      return false if current && @recorded_at < current

      @operation_stop.update_columns(
        status: @status,
        eta: @eta,
        status_updated_at: @recorded_at,
        updated_at: Time.current
      )
      true
    end
    # rubocop:enable Naming/PredicateMethod

  end
end
