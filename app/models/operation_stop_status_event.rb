# frozen_string_literal: true

class OperationStopStatusEvent < ApplicationRecord
  SOURCES = %w[mobile api device system import backoffice demo].freeze
  # Statuses that may carry an optional GPS fix from the mobile driver UI.
  POSITION_STATUSES = %w[delivered exception undelivered].freeze

  belongs_to :operation_stop

  validates :recorded_at, :source, presence: true
  validates :source, inclusion: { in: SOURCES }

  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  def set_creation_date
    self.created_at ||= Time.current
  end

  def position
    data = payload.is_a?(Hash) ? payload : {}
    lat = data['lat']
    lng = data['lng']
    return nil if lat.blank? || lng.blank?

    lat_f = Float(lat, exception: false)
    lng_f = Float(lng, exception: false)
    return nil unless lat_f && lng_f

    { lat: lat_f, lng: lng_f }
  end
end
