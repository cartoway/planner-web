class V100::Entities::Vehicle < V100::Entities::VehicleWithoutVehicleUsage
  def self.entity_name
    'V100_Vehicle'
  end

  expose(:vehicle_usages, using: V100::Entities::VehicleUsage, documentation: { type: V100::Entities::VehicleUsage, is_array: true })
end
