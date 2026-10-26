# frozen_string_literal: true

class V01::Entities::Operation < Grape::Entity
  def self.entity_name
    'V01_Operation'
  end

  expose :id, documentation: { type: Integer }
  expose :planning_id, documentation: { type: Integer }
  expose :date, documentation: { type: Date }
  expose :name, documentation: { type: String }
  expose :ref, documentation: { type: String }
  expose :status, documentation: { type: String }
  expose :published_at, documentation: { type: DateTime }
  expose :synced_at, documentation: { type: DateTime }
  expose :closed_at, documentation: { type: DateTime }
  expose :cancelled_at, documentation: { type: DateTime }
  expose :planning_snapshot, documentation: { type: Hash }
  expose :deliverable_units_snapshot, documentation: { type: Hash }
  # Omitted from GET /operations list; present on GET /operations/:id, publish and sync (type: :full).
  expose :operation_routes, using: V01::Entities::OperationRoute, documentation: { is_array: true, desc: 'Routes snapshot. Only included on detail/publish/sync responses, not on GET /operations list.' }, if: ->(_operation, options) { options[:type] == :full }
end
