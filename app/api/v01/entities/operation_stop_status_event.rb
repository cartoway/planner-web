# frozen_string_literal: true

class V01::Entities::OperationStopStatusEvent < Grape::Entity
  def self.entity_name
    'V01_OperationStopStatusEvent'
  end

  expose :id
  expose :status
  expose :eta
  expose :recorded_at
  expose :source
  expose :actor_ref
  expose :created_at
end
