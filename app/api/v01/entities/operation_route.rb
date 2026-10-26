# frozen_string_literal: true

class V01::Entities::OperationRoute < Grape::Entity
  def self.entity_name
    'V01_OperationRoute'
  end

  expose :id, documentation: { type: Integer }
  expose :index, documentation: { type: Integer, desc: 'Order among routes in the operation.' }
  expose :ref, documentation: { type: String }
  expose :color, documentation: { type: String }
  expose :sync_state, documentation: { type: String, desc: 'Snapshot sync state relative to the planning (e.g. synced, outdated).' }
  expose :route_id, documentation: { type: Integer, desc: 'Source planning route id.' }
  expose :vehicle_id, documentation: { type: Integer }
  expose :vehicle_usage_id, documentation: { type: Integer }
  expose :vehicle_snapshot, documentation: { type: Hash }
  expose :vehicle_usage_snapshot, documentation: { type: Hash }
  expose :route_snapshot, documentation: { type: Hash }
  expose :custom_attributes, documentation: { type: Hash }
  expose :departure_status, documentation: { type: String }
  expose :departure_eta, documentation: { type: DateTime }
  expose :departure_status_updated_at, documentation: { type: DateTime }
  expose :arrival_status, documentation: { type: String }
  expose :arrival_eta, documentation: { type: DateTime }
  expose :arrival_status_updated_at, documentation: { type: DateTime }
  expose :last_sent_at, documentation: { type: DateTime, desc: 'Last time this operation route was sent to a device. Distinct from planning route last_sent_at.' }
  expose :last_sent_to, documentation: { type: String, desc: 'Device/provider of last send (e.g. deliver).' }
  expose :operation_stops, using: V01::Entities::OperationStop, documentation: { is_array: true, desc: 'Stops snapshot. Included when Operation is presented with type=:full.' }, if: ->(_route, options) { options[:type] == :full }
end
