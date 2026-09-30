# frozen_string_literal: true

class VehiclePosition < ApplicationRecord
  DEFAULT_RETENTION_DAYS = 60
  MAX_RETENTION_DAYS = 365

  belongs_to :customer
  belongs_to :vehicle, optional: true
  belongs_to :operation, optional: true
  belongs_to :operation_route

  validates :lat, :lng, :positioned_at, :received_at, :source, presence: true

  before_update { raise ActiveRecord::ReadOnlyRecord }

  def set_creation_date
    self.created_at ||= Time.current
  end

  # CNIL-oriented purge: each customer's retention (default 60 days, capped at 1 year).
  def self.purge_stale!
    deleted = 0
    Customer.find_each do |customer|
      days = (customer.vehicle_position_retention_days.presence || DEFAULT_RETENTION_DAYS).to_i
      days = days.clamp(1, MAX_RETENTION_DAYS)
      deleted += where(customer_id: customer.id).where('positioned_at < ?', days.days.ago).delete_all
    end
    deleted
  end
end
