# frozen_string_literal: true

class V01::Entities::OperationStop < Grape::Entity
  def self.entity_name
    'V01_OperationStop'
  end

  expose :id, documentation: { type: Integer }
  expose :kind, documentation: { type: String, desc: 'Stop kind: visit, store, reload, rest, etc.' }
  expose :index, documentation: { type: Integer }
  expose :active, documentation: { type: 'Boolean' }
  expose :locked, documentation: { type: 'Boolean' }
  expose :sync_state, documentation: { type: String, desc: 'Snapshot sync state relative to the planning stop.' }
  expose :status, documentation: { type: String, desc: 'Driver status (e.g. pending, completed).' }
  expose :eta, documentation: { type: DateTime }
  expose :status_updated_at, documentation: { type: DateTime }
  expose :actual_quantities, documentation: { type: Hash, desc: 'Quantities reported by the driver/device.' }
  expose :custom_attributes, documentation: { type: Hash }
  expose(:cursor_updated, documentation: { type: 'Boolean' }, if: ->(_stop, options) { options.key?(:cursor_updated) }) { |_stop, options| options[:cursor_updated] }
  expose :destination_snapshot, documentation: { type: Hash }
  expose :visit_snapshot, documentation: { type: Hash }
  expose :store_snapshot, documentation: { type: Hash }
  expose :stop_snapshot, documentation: { type: Hash }
  expose :operation_stop_status_events, using: V01::Entities::OperationStopStatusEvent, as: :status_events,
                                        documentation: { is_array: true },
                                        if: ->(_stop, options) { options[:with_events] }
  expose(:photos, documentation: { is_array: true }, if: ->(_stop, options) { options[:with_media] }) { |stop| stop.serialized_photos }
  expose(:signature, documentation: { type: Hash }, if: ->(_stop, options) { options[:with_media] }) { |stop| stop.serialized_signature }
end
