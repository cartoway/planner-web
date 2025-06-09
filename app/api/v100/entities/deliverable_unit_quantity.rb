class V100::Entities::DeliverableUnitQuantity < Grape::Entity
  def self.entity_name
    'V100_DeliverableUnitQuantity'
  end

  expose(:deliverable_unit_id, documentation: { type: Integer })
  expose(:quantity, documentation: { type: Float })
end
