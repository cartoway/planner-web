class PlanningsZoning < ApplicationRecord
  belongs_to :planning
  belongs_to :zoning

  validates :zoning_id, uniqueness: { scope: :planning_id }
end
