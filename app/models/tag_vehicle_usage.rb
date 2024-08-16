class TagVehicleUsage < ApplicationRecord
  belongs_to :vehicle_usage
  belongs_to :tag
end
