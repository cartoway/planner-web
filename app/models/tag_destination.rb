class TagDestination < ApplicationRecord
  belongs_to :destination
  belongs_to :tag

  validates :tag_id, uniqueness: { scope: :destination_id }
end
