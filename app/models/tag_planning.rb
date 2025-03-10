class TagPlanning < ApplicationRecord
  belongs_to :planning
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :planning_id }
end
