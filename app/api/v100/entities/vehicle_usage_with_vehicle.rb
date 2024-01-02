class V100::Entities::VehicleUsageWithVehicle < V100::Entities::VehicleUsage
  def self.entity_name
    'V100_VehicleUsageWithVehicle'
  end

  expose(:vehicle, using: V100::Entities::VehicleWithoutVehicleUsage, documentation: { type: V100::Entities::VehicleWithoutVehicleUsage })
end
