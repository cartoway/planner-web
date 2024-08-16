class TagDestination < ApplicationRecord
  belongs_to :destination
  belongs_to :tag
end
