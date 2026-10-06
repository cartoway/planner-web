# frozen_string_literal: true

class OperationDeliveryTracking < ApplicationRecord
  TTL_AFTER_DATE = 48.hours

  belongs_to :operation
  # destination_id is a frozen publish-time identity, not a live FK (planning/destinations may be deleted).
  belongs_to :destination, optional: true

  validates :token, :expires_at, :destination_id, presence: true
  validates :token, uniqueness: true
  validates :destination_id, uniqueness: { scope: :operation_id }

  before_validation :ensure_token, on: :create
  before_validation :ensure_expires_at, on: :create

  scope :active, -> { where('expires_at > ?', Time.current) }
  scope :with_destination, -> { includes(:destination) }

  def expired?
    expires_at <= Time.current
  end

  def visit_stops
    return @preloaded_visit_stops if instance_variable_defined?(:@preloaded_visit_stops)

    OperationStop.visit_stops_for_destinations(operation, destination_id)
  end

  def preloaded_visit_stops=(stops)
    @preloaded_visit_stops = Array(stops)
  end

  # Batch-load visit_stops for a tracking collection (Planning#preload_* style).
  def self.preload_visit_stops!(trackings)
    trackings = Array(trackings).compact
    return trackings if trackings.empty?

    pending = trackings.reject { |tracking| tracking.instance_variable_defined?(:@preloaded_visit_stops) }
    return trackings if pending.empty?

    pending.group_by(&:operation_id).each_value do |group|
      operation = group.first.operation
      stops = OperationStop.visit_stops_for_destinations(operation, group.map(&:destination_id)).to_a
      by_destination = stops.group_by { |stop| stop.destination_identity }
      group.each do |tracking|
        tracking.preloaded_visit_stops = by_destination[tracking.destination_id] || []
      end
    end
    trackings
  end

  def turbo_stream_name
    "delivery_tracking_#{token}"
  end

  def self.expires_at_for(operation)
    operation.date.end_of_day + TTL_AFTER_DATE
  end

  def self.ensure_for!(operation)
    return unless connection.table_exists?(table_name)

    destination_ids = operation.operation_stops
                               .executable
                               .visits
                               .pluck(:destination_id, Arel.sql("destination_snapshot->>'id'"))
                               .flat_map { |destination_id, snapshot_id|
                                 [destination_id, snapshot_id.presence&.to_i].select { |id| id.to_i.positive? }
                               }
                               .uniq
    return if destination_ids.empty?

    existing = where(operation_id: operation.id, destination_id: destination_ids).pluck(:destination_id).to_set
    expires = expires_at_for(operation)
    (destination_ids - existing.to_a).each do |destination_id|
      create!(operation: operation, destination_id: destination_id, expires_at: expires)
    end
  end

  private

  def ensure_token
    self.token ||= SecureRandom.urlsafe_base64(24)
  end

  def ensure_expires_at
    self.expires_at ||= self.class.expires_at_for(operation) if operation
  end
end
