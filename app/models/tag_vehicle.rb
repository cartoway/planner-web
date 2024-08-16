class TagVehicle < ApplicationRecord
  belongs_to :vehicle
  belongs_to :tag
end
