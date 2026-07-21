class V100::Entities::VehicleWithoutVehicleUsage < Grape::Entity
  def self.entity_name
    'V100_VehicleWithoutVehicleUsage'
  end

  expose(:id, documentation: { type: Integer })
  expose(:ref, documentation: { type: String })
  expose(:name, documentation: { type: String })
  expose(:contact_email, documentation: { type: String })
  expose(:phone_number, documentation: { type: String })
  expose(:emission, documentation: { type: Float })
  expose(:consumption, documentation: { type: Integer })
  expose(:capacity, documentation: { type: Integer, desc: 'Deprecated, use capacities instead.' }) { |m|
    if m.capacities && m.customer.deliverable_units.size == 1
      capacities = m.capacities.values
      capacities[0] if capacities.size == 1
    end
  }
  expose(:capacity_unit, documentation: { type: String, desc: 'Deprecated, use capacities and deliverable_unit entity instead.' }) { |m|
    if m.capacities && m.customer.deliverable_units.size == 1
      deliverable_unit_ids = m.capacities.keys
      m.customer.deliverable_units[0].label if deliverable_unit_ids.size == 1
    end
  }
  expose(:capacities, using: V100::Entities::DeliverableUnitQuantity, documentation: { type: V100::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    m.capacities ? m.capacities.to_a.collect{ |a| {deliverable_unit_id: a[0], quantity: a[1]} } : []
  }
  expose(:color, documentation: { type: String, desc: 'Color code with #. For instance: #FF0000' })
  expose(:fuel_type, documentation: { type: String })
  expose(:router_id, documentation: { type: Integer })
  expose(:router_dimension, documentation: { type: String, values: ::Router::DIMENSION.keys })
  expose(:router_options, using: V100::Entities::RouterOptions, documentation: { type: V100::Entities::RouterOptions })
  expose(:speed_multiplicator, documentation: { type: Float, desc: 'Deprecated, use speed_multiplier instead.' }) { |m| m.speed_multiplier }
  expose(:speed_multiplier, documentation: { type: Float })
  expose(:max_distance, documentation: { type: Integer, desc: 'Maximum achievable distance in meters' })
  expose(:max_ride_distance, documentation: { type: Integer, desc: 'Maximum riding distance between two stops within a route in meters' })
  expose(:max_ride_duration, documentation: { type: Integer, desc: 'Maximum riding time between two stops within a route (HH:MM)' })
  expose(:tag_ids, documentation: { type: Integer, is_array: true })
  # Devices
  # add auth for : orange_id, teksat_id, tomtom_id
  expose(:devices, documentation: {type: Hash})
  expose(:custom_attributes_typed_hash, documentation: {type: Hash, desc: 'Additional properties'}, as: :custom_attributes)
end
