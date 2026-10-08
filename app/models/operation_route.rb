# frozen_string_literal: true

class OperationRoute < ApplicationRecord
  SYNC_STATES = %w[active orphaned cancelled].freeze

  belongs_to :operation
  belongs_to :route, optional: true
  belongs_to :vehicle_usage, optional: true
  belongs_to :vehicle, optional: true
  has_many :operation_stops, dependent: :destroy
  has_many :vehicle_positions, dependent: :delete_all

  validates :sync_state, inclusion: { in: SYNC_STATES }

  scope :active_sync, -> { where(sync_state: 'active') }
  scope :planned, -> { active_sync.where(unassigned: false) }
  scope :includes_for_show, -> {
    includes(:operation, :vehicle, :operation_stops)
  }

  def progress_counts
    stops = operation_stops.select { |stop| stop.sync_state == 'active' && stop.kind != 'rest' && stop.active != false }
    total = stops.size
    treated = stops.count { |stop| OperationStop::TREATED_STATUSES.include?(stop.status.to_s.downcase) }
    progress = total.zero? ? 0.0 : treated.to_f / total
    { treated: treated, total: total, progress: progress }
  end

  def vehicle_name
    vehicle_snapshot['name'].presence || ref
  end

  def driver_email
    vehicle_snapshot['contact_email'].presence || vehicle&.contact_email
  end

  def driver_phone
    vehicle_snapshot['phone_number'].presence || vehicle&.phone_number
  end

  def mark_sent!(channel)
    update_columns(last_sent_at: Time.current, last_sent_to: channel, updated_at: Time.current)
  end

  def expired?
    day = operation.date
    return false if day.blank?

    last_stop = operation_stops.executable.where(kind: 'visit').order(:index).last
    seconds = last_stop&.stop_snapshot&.[]('time')
    return false if seconds.blank?

    day + seconds.to_i.seconds + 12.hours < Time.current
  end

  def vehicle_color
    color.presence || vehicle_snapshot['color'].presence || '#888888'
  end

  def router_name
    locales = vehicle_snapshot['router_name_locale']
    if locales.is_a?(Hash) && locales.present?
      return locales[I18n.locale.to_s].presence ||
             locales[I18n.default_locale.to_s].presence ||
             locales.values.find(&:present?)
    end

    # Legacy snapshots stored a single translated string.
    vehicle_snapshot['router_name'].presence || vehicle&.default_router&.translated_name
  end

  def list_depots
    [
      list_depot('store_start', 'start', departure_status),
      list_depot('store_stop', 'end', arrival_status)
    ]
  end

  def depot_for(role)
    case role.to_s
    when 'start' then list_depot('store_start', 'start', departure_status)
    when 'end' then list_depot('store_stop', 'end', arrival_status)
    end
  end

  # Route depots have no status_events table; rebuild from cursor + loading stash.
  def depot_status_events(role)
    case role.to_s
    when 'start'
      reconstruct_depot_events(
        status: departure_status,
        updated_at: departure_status_updated_at,
        loading_at: stashed_loading_at('departure')
      )
    when 'end'
      reconstruct_depot_events(
        status: arrival_status,
        updated_at: arrival_status_updated_at,
        loading_at: stashed_loading_at('arrival')
      )
    else
      []
    end
  end

  def depot_status_label(status)
    return if status.blank?

    key = status.to_s.downcase
    I18n.t("plannings.edit.stop_store_status.#{key}", default: I18n.t("plannings.edit.stop_status.#{key}", default: status))
  end

  def depot_status_updated_at(role)
    role.to_s == 'start' ? departure_status_updated_at : arrival_status_updated_at
  end

  def depot_loading_at(role)
    role.to_s == 'start' ? stashed_loading_at('departure') : stashed_loading_at('arrival')
  end

  def clock_on_operation_day(time)
    return if time.blank?

    date = operation.date
    clock = I18n.l(time, format: :hour_minute)
    return clock if date.blank?

    offset = (time.to_date - date).to_i
    return clock if offset.zero?

    delta = offset.positive? ? "+#{offset}" : offset.to_s
    "#{clock} #{I18n.t('operations.show.day_shift', delta: delta)}"
  end

  def started?
    return false if unassigned || vehicle_id.nil?

    departure_status.present? || operation_stops.any? { |stop| stop.status.present? }
  end

  def board
    stops = operation_stops.select { |stop| stop.sync_state == 'active' && stop.kind != 'rest' && stop.active != false }
    delivered = stops.count { |stop| stop.phase == 'delivered' }
    failed = stops.count { |stop| stop.phase == 'failed' }
    exception = stops.count { |stop| stop.phase == 'exception' }
    delays = stops.filter_map(&:delay_minutes)
    distance = route_snapshot['distance'].to_f
    late_minutes = delays.select { |minutes| minutes > OperationStop::LATE_AFTER_MINUTES }
    {
      delivered: delivered,
      failed: failed,
      exception: exception,
      late: stops.count { |stop| stop.phase == 'late' },
      upcoming: stops.count { |stop| stop.phase == 'upcoming' },
      current: stops.count { |stop| stop.phase == 'current' },
      total: stops.size,
      delay: (delays.empty? ? nil : late_minutes.sum),
      distance: distance,
      units: unit_totals(stops)
    }
  end

  def latest_position
    vehicle_positions.order(positioned_at: :desc).first
  end

  def planned_clock(seconds)
    Operations::Snapshots.clock_on(operation.date, seconds)
  end

  private

  def stashed_loading_at(leg)
    raw = custom_attributes.is_a?(Hash) && custom_attributes["_#{leg}_loading_at"]
    return if raw.blank?

    Time.zone.parse(raw.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def reconstruct_depot_events(status:, updated_at:, loading_at:)
    code = status.to_s.downcase.presence
    return [] if code.blank?

    events = []
    if code == 'finished' && loading_at.present?
      events << { status: 'atstore', recorded_at: loading_at }
    end
    events << { status: code, recorded_at: updated_at } if updated_at.present?
    events
  end

  def unit_totals(stops)
    catalog = operation.quantity_catalog
    capacities = vehicle_snapshot['capacities'] || {}
    totals = {}
    stops.each do |stop|
      snap = stop.visit_snapshot || {}
      explicit = %w[deliveries pickups].flat_map { |key| snap[key].is_a?(Hash) ? snap[key].keys.map(&:to_s) : [] }
      (catalog.keys | explicit).each do |unit_id|
        unit = catalog[unit_id] || {}
        delivery = operation.resolved_quantity(snap['deliveries'], unit_id, unit['default_delivery'])
        pickup = operation.resolved_quantity(snap['pickups'], unit_id, unit['default_pickup'])
        next if delivery.nil? && pickup.nil?

        delivery = delivery.to_f
        pickup = pickup.to_f
        next if delivery.zero? && pickup.zero?

        row = snap.dig('deliveries', unit_id) || snap.dig('pickups', unit_id) || {}
        bucket = totals[unit_id] ||= { delivery: 0.0, pickup: 0.0, delivered: 0.0, collected: 0.0, label: row['label'] }
        bucket[:delivery] += delivery
        bucket[:pickup] += pickup
        if stop.phase == 'delivered'
          bucket[:delivered] += stop.actual_quantity('deliveries', unit_id) || delivery
          bucket[:collected] += stop.actual_quantity('pickups', unit_id) || pickup
        end
      end
    end
    totals.filter_map do |unit_id, sums|
      unit = catalog[unit_id] || {}
      {
        id: unit_id,
        label: unit['label'].presence || sums[:label].presence || unit['ref'].presence || unit_id,
        icon: unit['icon'].presence || DeliverableUnit::ICON_DEFAULT,
        delivery: sums[:delivery],
        pickup: sums[:pickup],
        delivered: sums[:delivered],
        collected: sums[:collected],
        capacity: capacities[unit_id] || capacities[unit_id.to_i]
      }
    end
  end

  def list_depot(store_key, time_key, status)
    place = (vehicle_usage_snapshot || {})[store_key]
    # Snapshot may be empty when the depot comes from the usage set default.
    place = Operations::Snapshots.place(vehicle_usage&.public_send("default_#{store_key}")) if place.blank?
    return if place.blank? || place['name'].blank?

    seconds = (route_snapshot || {})[time_key].presence
    seconds ||= Operations::Snapshots.schedule_seconds(route.route_data, time_key.to_sym) if route&.route_data
    {
      name: place['name'],
      time: planned_clock(seconds),
      status: status.presence,
      lat: place['lat'],
      lng: place['lng'],
      address: [place['street'], place['postalcode'], place['city']].compact_blank.join(', '),
      phone: place['phone_number'],
      ref: place['ref']
    }
  end
end
