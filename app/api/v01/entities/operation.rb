# frozen_string_literal: true

class V01::Entities::Operation < Grape::Entity
  def self.entity_name
    'V01_Operation'
  end

  expose :id
  expose :planning_id
  expose :date
  expose :name
  expose :ref
  expose :status
  expose :published_at
  expose :synced_at
  expose :closed_at
  expose :cancelled_at
  expose :planning_snapshot
  expose :deliverable_units_snapshot
  expose :operation_routes, using: V01::Entities::OperationRoute, if: ->(_operation, options) { options[:type] == :full }
end
