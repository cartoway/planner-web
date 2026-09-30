# frozen_string_literal: true

class V01::Entities::OperationStop < Grape::Entity
  def self.entity_name
    'V01_OperationStop'
  end

  expose :id
  expose :kind
  expose :index
  expose :sync_state
  expose :status
  expose :eta
  expose :status_updated_at
  expose(:cursor_updated, if: ->(_stop, options) { options.key?(:cursor_updated) }) { |_stop, options| options[:cursor_updated] }
  expose :destination_snapshot
  expose :visit_snapshot
  expose :store_snapshot
  expose :stop_snapshot
end
