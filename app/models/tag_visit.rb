class TagVisit < ApplicationRecord
  belongs_to :visit
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :visit_id }
end
