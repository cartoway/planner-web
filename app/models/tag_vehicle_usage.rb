class TagVehicleUsage < ApplicationRecord
  belongs_to :vehicle_usage
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :vehicle_usage_id }
end
