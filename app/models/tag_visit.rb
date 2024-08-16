class TagVisit < ApplicationRecord
  belongs_to :visit
  belongs_to :tag
end
