# frozen_string_literal: true

module DeliverDemo
  class Control
    class NotEnabled < StandardError; end
    class NotOpen < StandardError; end
    class AlreadyRunning < StandardError; end

    def self.start!(operation)
      new(operation).start!
    end

    def self.stop!(operation)
      new(operation).stop!
    end

    def self.reset!(operation)
      new(operation).reset!
    end

    def initialize(operation)
      @operation = operation
    end

    def start!
      raise NotEnabled unless DeliverDemo.enabled?(@operation.customer)
      raise NotOpen unless @operation.open?

      if @operation.demo_job_id.present?
        raise AlreadyRunning if @operation.demo_job.present?

        @operation.update_column(:demo_job_id, nil)
      end

      delayed = Delayed::Job.enqueue(DeliverDemoJob.new(@operation.id, {}), run_at: Time.current)
      @operation.update_column(:demo_job_id, delayed.id)
      @operation
    end

    def stop!
      clear_job!
      @operation
    end

    # Clears execution traces (GPS + statuses) but keeps planning snapshots.
    def reset!
      raise NotEnabled unless DeliverDemo.enabled?(@operation.customer)
      raise NotOpen unless @operation.open?

      clear_job!
      ActiveRecord::Base.transaction do
        VehiclePosition.where(operation_id: @operation.id).delete_all
        stop_ids = @operation.operation_stops.pluck(:id)
        OperationStopStatusEvent.where(operation_stop_id: stop_ids).delete_all if stop_ids.any?
        @operation.operation_stops.update_all(status: nil, eta: nil, status_updated_at: nil, updated_at: Time.current)
        @operation.operation_routes.update_all(
          departure_status: nil,
          departure_status_updated_at: nil,
          departure_eta: nil,
          arrival_status: nil,
          arrival_status_updated_at: nil,
          arrival_eta: nil,
          updated_at: Time.current
        )
      end
      broadcast_refresh
      @operation.reload
    end

    private

    def clear_job!
      if @operation.demo_job
        @operation.demo_job.destroy
      elsif @operation.demo_job_id.present?
        Delayed::Job.where(id: @operation.demo_job_id).delete_all
      end
      @operation.update_column(:demo_job_id, nil) if @operation.demo_job_id.present?
    end

    def broadcast_refresh
      # Omit request-id: Turbo ignores refreshes tagged with the clicker's current request.
      content = ApplicationController.helpers.turbo_stream_refresh_tag(request_id: nil)
      Turbo::StreamsChannel.broadcast_stream_to(@operation, content: content)
    rescue StandardError => e
      Rails.logger.warn("operation demo reset refresh failed: #{e.class}: #{e.message}")
    end
  end
end
