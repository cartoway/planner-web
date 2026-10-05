# frozen_string_literal: true

class V01::Entities::OperationRoute < Grape::Entity
  def self.entity_name
    'V01_OperationRoute'
  end

  expose :id
  expose :index
  expose :ref
  expose :color
  expose :unassigned
  expose :sync_state
  expose :route_id
  expose :vehicle_id
  expose :vehicle_usage_id
  expose :vehicle_snapshot
  expose :vehicle_usage_snapshot
  expose :route_snapshot
  expose :custom_attributes
  expose :departure_status
  expose :departure_eta
  expose :departure_status_updated_at
  expose :arrival_status
  expose :arrival_eta
  expose :arrival_status_updated_at
  expose :last_sent_at
  expose :last_sent_to
  expose :operation_stops, using: V01::Entities::OperationStop, if: ->(_route, options) { options[:type] == :full }
end
