# frozen_string_literal: true

class OperationStop < ApplicationRecord
  KINDS = %w[visit rest store].freeze
  SYNC_STATES = %w[active orphaned cancelled].freeze
  # Terminal field statuses already used by the planning stop catalog.
  TREATED_STATUSES = %w[delivered finished rejected undelivered exception].freeze

  belongs_to :operation_route
  belongs_to :stop, optional: true
  belongs_to :visit, optional: true
  belongs_to :destination, optional: true
  belongs_to :store, optional: true
  belongs_to :store_reload, optional: true
  has_many :operation_stop_status_events, dependent: :delete_all
  has_many_attached :photos
  has_one_attached :signature
  include ProofAttachments

  validates :kind, inclusion: { in: KINDS }
  validates :sync_state, inclusion: { in: SYNC_STATES }
  validates :index, presence: true
  validate :visit_snapshot_present, if: -> { kind == 'visit' }

  scope :active_sync, -> { where(sync_state: 'active') }
  scope :executable, -> { active_sync.where.not(active: false) }
  scope :past_operations, -> {
    joins(operation_route: :operation).where(operations: { status: 'historized' })
  }
  scope :current_operations, -> {
    joins(operation_route: :operation).where(operations: { status: 'in_progress' })
  }

  def self.for_destination(destination, include_past: false)
    visit_ids = destination.visits.pluck(:id)
    visit_ids = [0] if visit_ids.empty?
    rel = linked_to_operation.where(
      'operation_stops.destination_id = ? OR operation_stops.visit_id IN (?)',
      destination.id,
      visit_ids
    )
    rel = rel.where(current_operation_sql) unless include_past
    rel.order('operations.date DESC', :index)
  end

  def self.for_visit(visit, include_past: false)
    rel = linked_to_operation.where(visit_id: visit.id)
    rel = rel.where(current_operation_sql) unless include_past
    rel.order('operations.date DESC', :index)
  end

  def self.linked_to_operation
    joins(operation_route: :operation)
      .merge(OperationRoute.where(unassigned: false))
      .where.not(active: false)
      .includes(:operation_stop_status_events, operation_route: :operation)
      .with_attached_photos
      .with_attached_signature
  end

  def self.current_operation_sql
    <<~SQL.squish
      operations.status = 'in_progress'
    SQL
  end

  def self.search_by_destination_info(query: nil, from: nil, to: nil, include_orphans: true, destination_id: nil, customer_id: nil)
    rel = joins(operation_route: :operation)
          .merge(OperationRoute.where(unassigned: false))
          .where.not(active: false)
    rel = rel.where(operations: { customer_id: customer_id }) if customer_id
    rel = rel.where(operations: { date: from..to }) if from && to
    rel = rel.where(sync_state: 'active') unless include_orphans
    rel = rel.where(destination_id: destination_id) if destination_id.present?
    if query.present?
      escaped = "%#{sanitize_sql_like(query.to_s.strip)}%"
      rel = rel.where(<<~SQL.squish, q: escaped)
        destination_snapshot->>'ref' ILIKE :q
        OR destination_snapshot->>'name' ILIKE :q
        OR destination_snapshot->>'street' ILIKE :q
        OR destination_snapshot->>'city' ILIKE :q
      SQL
    end
    rel
  end

  def visit?
    kind == 'visit'
  end

  def clock_label(seconds)
    return if seconds.blank?

    total = seconds.to_i
    format('%<h>02d:%<m>02d', h: (total / 3600) % 24, m: (total % 3600) / 60)
  end

  def duration_label(seconds)
    return if seconds.blank?

    Time.at(seconds.to_i).utc.strftime('%H:%M:%S')
  end

  def time_windows_label
    visit = visit_snapshot || {}
    ranges = (1..2).filter_map { |index|
      start_at = clock_label(visit["time_window_start_#{index}"])
      end_at = clock_label(visit["time_window_end_#{index}"])
      next if start_at.blank? && end_at.blank?

      [start_at, end_at].compact.join(' – ')
    }
    ranges.join(' et ').presence
  end

  def destination_duration_label
    seconds = destination_snapshot&.[]('duration')
    if seconds.blank? && destination
      raw = destination.read_attribute_before_type_cast(:duration)
      seconds = raw if raw.is_a?(Numeric) || raw.to_s.match?(/\A\d+\z/)
    end
    duration_label(seconds)
  end

  def planned_at
    Operations::Snapshots.timestamp_on(operation_route.operation.date, stop_snapshot['time'])
  end
  alias planned_arrival_at planned_at

  def passage_time
    Operations::Snapshots.clock_on(operation_route.operation.date, stop_snapshot['time'])
  end
  alias planned_arrival_clock passage_time

  def service_duration_seconds
    raw = visit_snapshot&.[]('duration') ||
          destination_snapshot&.[]('duration') ||
          store_snapshot&.[]('duration')
    return 0 if raw.blank?

    raw.to_i
  end

  def planned_departure_at
    at = planned_arrival_at
    return if at.blank?

    at + service_duration_seconds.seconds
  end

  def planned_departure_clock
    clock_on_operation_day(planned_departure_at)
  end

  def actual_departure_at
    return unless treated?

    status_updated_at
  end

  def actual_arrival_at
    at = actual_departure_at
    return if at.blank?

    at - service_duration_seconds.seconds
  end

  def actual_arrival_clock
    clock_on_operation_day(actual_arrival_at)
  end

  def actual_departure_clock
    clock_on_operation_day(actual_departure_at)
  end

  FAILED_STATUSES = %w[rejected undelivered].freeze
  EXCEPTION_STATUSES = %w[exception].freeze
  DONE_STATUSES = %w[delivered finished].freeze
  CURRENT_STATUSES = %w[intransit atstore inprocessing].freeze
  LATE_AFTER_MINUTES = 5

  def treated?
    TREATED_STATUSES.include?(status.to_s.downcase)
  end

  def phase
    code = status.to_s.downcase
    return 'failed' if FAILED_STATUSES.include?(code)
    return 'exception' if EXCEPTION_STATUSES.include?(code)
    return 'delivered' if DONE_STATUSES.include?(code)
    return 'started' if code == 'started'
    return 'current' if CURRENT_STATUSES.include?(code)
    return 'late' if eta_late?

    'upcoming'
  end

  def status_label
    code = status.to_s.downcase
    return if code.blank?

    scope = case kind
            when 'rest' then 'plannings.edit.stop_rest_status'
            when 'store' then 'plannings.edit.stop_store_status'
            else 'plannings.edit.stop_status'
            end
    I18n.t("#{scope}.#{code}", default: I18n.t("plannings.edit.stop_status.#{code}", default: status))
  end

  # Delay vs planned departure (service end), not arrival.
  def delay_minutes
    return unless treated?

    planned = planned_departure_at
    actual = actual_departure_at
    return if planned.blank? || actual.blank?

    ((actual - planned) / 60.0).round
  end

  def actual_quantity(kind, unit_id)
    bag = actual_quantities.is_a?(Hash) ? actual_quantities[kind.to_s] : nil
    return if bag.blank?

    value = bag[unit_id.to_s]
    value = bag[unit_id.to_i] if value.nil?
    return if value.nil?

    value.to_f
  end

  def quantity_lines
    snap = visit_snapshot || {}
    catalog = operation_route.operation.quantity_catalog
    explicit = %w[deliveries pickups].flat_map { |key| snap[key].is_a?(Hash) ? snap[key].keys.map(&:to_s) : [] }
    (catalog.keys | explicit).flat_map do |unit_id|
      unit = catalog[unit_id] || {}
      %w[deliveries pickups].filter_map do |key|
        default_key = key == 'deliveries' ? 'default_delivery' : 'default_pickup'
        value = operation_route.operation.resolved_quantity(snap[key], unit_id, unit[default_key])
        next if value.nil? || value.zero?

        row = snap.dig(key, unit_id) || {}
        {
          kind: key,
          unit_id: unit_id,
          label: row['label'].presence || unit['label'].presence || row['ref'].presence || key,
          unit_icon: unit['icon'].presence || DeliverableUnit::ICON_DEFAULT,
          value: value
        }
      end
    end
  end

  def fiche_attributes
    customer = operation_route.operation.customer
    classes = case kind
              when 'visit' then %w[visit stop_visit]
              when 'store' then %w[stop_store]
              else []
              end
    return [] if classes.empty?

    stop_values = (stop_snapshot['custom_attributes'] || {}).merge(custom_attributes || {})
    visit_values = visit_snapshot['custom_attributes'].presence
    visit_values = visit.custom_attributes || {} if visit_values.blank? && visit_id.present?
    visit_values ||= {}
    customer.custom_attributes.where(object_class: classes).order(:name).filter_map do |definition|
      bag = definition.object_class == 'visit' ? visit_values : stop_values
      key = CustomAttribute.storage_key_for(definition.name)
      # Array defaults are the option catalog, not a selected value.
      next unless bag.key?(key) || (!definition.array? && definition.default_value.present?)

      value = bag.key?(key) ? bag[key] : definition.typed_default_value
      next if definition.array? && value.blank?

      { definition: definition, value: value }
    end
  end

  def parcel_count
    snap = visit_snapshot || {}
    %w[deliveries pickups].sum { |key| quantity_total(snap[key]) }
  end

  # Treated status cursor is the service end (departure / livraison terminée).
  def actual_clock
    actual_departure_clock
  end

  def clock_on_operation_day(time)
    return if time.blank?

    date = operation_route.operation.date
    clock = I18n.l(time, format: :hour_minute)
    return clock if date.blank?

    offset = (time.to_date - date).to_i
    return clock if offset.zero?

    delta = offset.positive? ? "+#{offset}" : offset.to_s
    "#{clock} #{I18n.t('operations.show.day_shift', delta: delta)}"
  end

  def list_fields
    place = place_snapshot
    {
      'name' => place['name'],
      'ref' => place['ref'],
      'visit_ref' => visit_snapshot['ref'],
      'street' => place['street'],
      'postalcode' => place['postalcode'],
      'city' => place['city'],
      'country' => place['country'],
      'lat' => place['lat'],
      'lng' => place['lng'],
      'detail' => place['detail'],
      'comment' => place['comment'],
      'phone_number' => place['phone_number'],
      'eta_formated' => (I18n.l(eta, format: :hour_minute) if eta),
      'status' => status,
      'visits' => visit?
    }
  end

  def delivery_note_available?
    visit? && stop_id.present? && Stop::DELIVERY_NOTE_STATUSES.include?(status.to_s.downcase)
  end

  def active_delivery_tracking
    return unless kind == 'visit'

    operation = operation_route&.operation
    return unless operation

    key = destination_id.presence || destination_snapshot&.[]('id')
    return unless key

    OperationDeliveryTracking.active.find_by(operation_id: operation.id, destination_id: key)
  end

  def document_items
    items = serialized_photos.map { |photo| { url: photo[:url], filename: photo[:filename], kind: 'photo' } }
    if stop&.photos&.attached?
      items.concat(stop.serialized_photos.map { |photo| { url: photo[:url], filename: photo[:filename], kind: 'photo' } })
    end
    signature_doc = serialized_signature
    signature_doc ||= stop.serialized_signature if stop&.signature&.attached?
    items << { url: signature_doc[:url], filename: signature_doc[:filename], kind: 'signature' } if signature_doc
    items
  end

  def proof_customer_id
    operation_route&.operation&.customer_id
  end

  def address_label
    snap = place_snapshot
    label = [snap['name'], snap['street'], snap['postalcode'], snap['city']].compact_blank.join(', ')
    return label if label.present?
    return I18n.t('stops.default.name_rest') if kind == 'rest'

    label
  end

  def lat
    raw = place_snapshot['lat']
    return if raw.blank?

    raw.to_f
  end

  def lng
    raw = place_snapshot['lng']
    return if raw.blank?

    raw.to_f
  end

  private

  def place_snapshot
    destination_snapshot.presence || store_snapshot.presence || rest_place_snapshot
  end

  # Legacy publishes left rest store_snapshot empty; fall back to usage snapshot.
  def rest_place_snapshot
    return {} unless kind == 'rest'

    operation_route&.vehicle_usage_snapshot&.[]('store_rest').presence || {}
  end

  def quantity_total(raw)
    values = raw.is_a?(Hash) ? raw.values : Array(raw)
    values.sum { |row| row.is_a?(Hash) ? row['value'].to_f : row.to_f }
  end

  def eta_late?
    planned = planned_at
    return false if eta.blank? || planned.blank?

    ((eta - planned) / 60.0) > LATE_AFTER_MINUTES
  end

  def visit_snapshot_present
    errors.add(:visit_snapshot, :blank) if visit_snapshot.blank?
  end

end
