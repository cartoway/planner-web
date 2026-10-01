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

  def expired?
    expires_at <= Time.current
  end

  def visit_stops
    operation.operation_stops
             .executable
             .where(kind: 'visit')
             .where(
               'operation_stops.destination_id = :id OR (operation_stops.destination_snapshot->>\'id\')::int = :id',
               id: destination_id
             )
             .joins(:operation_route)
             .merge(OperationRoute.where(unassigned: false))
             .includes(:operation_stop_status_events, operation_route: [:operation, :vehicle_positions])
             .order('operation_routes.index', 'operation_stops.index')
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
                               .where(kind: 'visit')
                               .filter_map { |stop| stop.destination_id.presence || stop.destination_snapshot&.[]('id') }
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
