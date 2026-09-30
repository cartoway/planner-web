# frozen_string_literal: true

class VehiclePosition < ApplicationRecord
  belongs_to :customer
  belongs_to :vehicle, optional: true
  belongs_to :operation, optional: true
  belongs_to :operation_route

  validates :lat, :lng, :positioned_at, :received_at, :source, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord }

  def set_creation_date
    self.created_at ||= Time.current
  end
end
