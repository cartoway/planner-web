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
      broadcast_page_refresh if cursor_updated
      @operation_stop.reload
      { event: event, cursor_updated: cursor_updated, operation_stop: @operation_stop }
    end

    private

    def clearing_transferred?
      @operation_stop.status.to_s.downcase == 'transferred' && @status.blank?
    end

    def broadcast_page_refresh
      operation = @operation_stop.operation_route&.operation
      return unless operation

      Turbo::StreamsChannel.broadcast_refresh_to(operation)
    rescue StandardError => error
      Rails.logger.warn("operation turbo refresh failed: #{error.class}: #{error.message}")
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
