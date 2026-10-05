# frozen_string_literal: true

class V01::Entities::OperationStopSearch < Grape::Entity
  def self.entity_name
    'V01_OperationStopSearch'
  end

  expose :id
  expose :operation_route_id
  expose(:operation_id) { |stop| stop.operation_route.operation_id }
  expose(:label) { |stop| stop.address_label }
  expose :index
  expose :kind
  expose :status
end
