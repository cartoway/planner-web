class V2::Entities::DeliverableUnitQuantity < Grape::Entity
  def self.entity_name
    'V2_DeliverableUnitQuantity'
  end

  expose(:deliverable_unit_id, documentation: { type: Integer })
  expose(:quantity, documentation: { type: Float })
  expose(:operation, documentation: { type: String, values: [:fill, :empty] })
end
