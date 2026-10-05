# frozen_string_literal: true

class V01::Entities::OperationStop < Grape::Entity
  def self.entity_name
    'V01_OperationStop'
  end

  expose :id
  expose :kind
  expose :index
  expose :active
  expose :locked
  expose :sync_state
  expose :status
  expose :eta
  expose :status_updated_at
  expose :actual_quantities
  expose :custom_attributes
  expose(:cursor_updated, if: ->(_stop, options) { options.key?(:cursor_updated) }) { |_stop, options| options[:cursor_updated] }
  expose :destination_snapshot
  expose :visit_snapshot
  expose :store_snapshot
  expose :stop_snapshot
  expose :operation_stop_status_events, using: V01::Entities::OperationStopStatusEvent, as: :status_events,
                                        if: ->(_stop, options) { options[:with_events] }
  expose(:photos, if: ->(_stop, options) { options[:with_media] }) { |stop| stop.serialized_photos }
  expose(:signature, if: ->(_stop, options) { options[:with_media] }) { |stop| stop.serialized_signature }
end
