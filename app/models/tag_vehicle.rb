class TagVehicle < ApplicationRecord
  belongs_to :vehicle
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :vehicle_id }
end
