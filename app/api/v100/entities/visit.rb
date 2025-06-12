class V100::Entities::Visit < Grape::Entity
  include QuantitiesEntityHelper

  def self.entity_name
    'V100_Visit'
  end

  expose(:id, documentation: { type: Integer })
  expose(:destination_id, documentation: { type: Integer })
  expose(:quantities, using: V100::Entities::DeliverableUnitQuantity, documentation: { type: V100::Entities::DeliverableUnitQuantity, is_array: true }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }
  expose(:time_window_start_1, documentation: { type: DateTime }) { |m| m.time_window_start_1_absolute_time_with_seconds }
  expose(:time_window_end_1, documentation: { type: DateTime }) { |m| m.time_window_end_1_absolute_time_with_seconds }
  expose(:time_window_start_2, documentation: { type: DateTime }) { |m| m.time_window_start_2_absolute_time_with_seconds }
  expose(:time_window_end_2, documentation: { type: DateTime }) { |m| m.time_window_end_2_absolute_time_with_seconds }
  expose(:priority, documentation: { type: Integer, desc: 'Insertion priority when optimizing (-4 to 4, 0 if not defined).' })
  expose(:ref, documentation: { type: String })
  expose(:duration, documentation: { type: DateTime, desc: 'Visit duration.' }) { |m| m.duration_absolute_time_with_seconds }
  expose(:duration_default, documentation: { type: DateTime }) { |m| m.destination.customer && m.destination.customer.visit_duration_absolute_time_with_seconds }
  expose(:tag_ids, documentation: { type: Integer, is_array: true })
  expose(:force_position, documentation: { type: String })
  expose(:custom_attributes_typed_hash, documentation: {type: Hash, desc: 'Additional properties'}, as: :custom_attributes)
end
