# frozen_string_literal: true

class Operation < ApplicationRecord
  STATUSES = %w[in_progress historized].freeze
  OPEN_STATUSES = %w[in_progress].freeze

  belongs_to :customer
  belongs_to :planning, optional: true
  has_many :operation_routes, dependent: :destroy
  has_many :operation_stops, through: :operation_routes
  has_many :vehicle_positions, dependent: :destroy

  validates :customer, :name, :date, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :date_locked_when_historized
  validate :routes_available_on_date, if: -> { open? && date_changed? && planning_id.present? }

  scope :open_status, -> { where(status: OPEN_STATUSES) }

  def open?
    OPEN_STATUSES.include?(status)
  end

  def date_locked_when_historized
    return unless persisted? && status == 'historized' && date_changed?

    errors.add(:base, I18n.t('operations.show.date_locked'))
  end

  def routes_available_on_date
    route_ids = operation_routes.where.not(route_id: nil).pluck(:route_id)
    return if route_ids.empty?

    conflict = planning.taken_route_ids(date: date, except_operation_id: id) & route_ids
    return if conflict.empty?

    errors.add(:base, I18n.t('operations.show.route_date_conflict'))
  end

  def current_structure?(planning_record = planning)
    return false unless planning_record

    structure_fingerprint == Operations::Snapshots.fingerprint(
      planning_record,
      visible_routes_only: custom_attributes['_visible_routes_only'] == true,
      route_ids: custom_attributes['_route_ids']
    )
  end

  def board
    routes = operation_routes.active_sync.includes(:operation_stops).to_a
    parts = routes.map(&:board)
    keys = %i[delivered failed exception late upcoming current total]
    summed = keys.index_with { |key| parts.sum { |part| part[key].to_i } }
    delays = parts.filter_map { |part| part[:delay] }
    sendable = routes.reject(&:unassigned)
    summed.merge(
      delay: (delays.sum if delays.any?),
      distance: parts.sum { |part| part[:distance].to_f },
      units: merged_units(parts.flat_map { |part| part[:units] }),
      rest: summed[:total] - summed[:delivered] - summed[:failed] - summed[:exception],
      sent: sendable.count { |route| route.last_sent_at.present? },
      routes: sendable.size,
      plan: plan_totals(sendable)
    )
  end

  def board_counts
    statuses = operation_stops.joins(:operation_route).merge(OperationRoute.active_sync).executable.where.not(kind: 'rest').pluck(:status)
    delivered = statuses.count { |status| OperationStop::DONE_STATUSES.include?(status.to_s.downcase) }
    failed = statuses.count { |status| OperationStop::FAILED_STATUSES.include?(status.to_s.downcase) }
    exception = statuses.count { |status| OperationStop::EXCEPTION_STATUSES.include?(status.to_s.downcase) }
    total = statuses.size
    { delivered: delivered, failed: failed, exception: exception, total: total, rest: total - delivered - failed - exception }
  end

  def plan_totals(routes)
    totals = Hash.new(0.0)
    %w[distance drive_time visits_duration wait_time rests_duration work_duration duration emission revenue].each do |key|
      totals[key] = routes.sum { |route| snapshot_number(route, key) }
    end
    totals['cost'] = routes.sum { |route| snapshot_cost(route) }
    totals
  end

  def snapshot_number(route, key)
    value = route.route_snapshot&.[](key)
    return value.to_f unless value.nil?

    live = route.route
    return 0.0 unless live

    case key
    when 'duration' then live.total_duration.to_f
    when 'work_duration' then live.work_duration.to_f
    else live.public_send(key).to_f
    end
  rescue NoMethodError
    0.0
  end

  def snapshot_cost(route)
    snap = route.route_snapshot || {}
    if snap.key?('cost_distance') || snap.key?('cost_fixed') || snap.key?('cost_time')
      return [snap['cost_distance'], snap['cost_fixed'], snap['cost_time']].compact.sum(&:to_f)
    end

    live = route.route
    return 0.0 unless live

    [live.cost_distance, live.cost_fixed, live.cost_time].compact.sum(&:to_f)
  end

  def quantity_catalog
    @quantity_catalog ||= begin
      snap = deliverable_units_snapshot || []
      rows = if snap.any? { |unit| unit.key?('default_delivery') || unit.key?('default_pickup') }
        snap
      else
        customer.deliverable_units.map { |unit|
          {
            'id' => unit.id, 'ref' => unit.ref, 'label' => unit.label, 'icon' => unit.icon,
            'default_delivery' => unit.default_delivery, 'default_pickup' => unit.default_pickup
          }
        }
      end
      rows.index_by { |unit| unit['id'].to_s }
    end
  end

  # Visit value wins, including an explicit zero. A missing value uses a non-null unit default.
  def resolved_quantity(raw, unit_id, default)
    row = raw.is_a?(Hash) ? (raw[unit_id] || raw[unit_id.to_i]) : nil
    if row.is_a?(Hash) && !row['value'].nil? && row['value'] != ''
      row['value'].to_f
    elsif default.nil?
      nil
    else
      default.to_f
    end
  end

  def merged_units(units)
    grouped = {}
    units.each do |unit|
      bucket = grouped[unit[:id].to_s] ||= unit.merge(delivery: 0.0, pickup: 0.0, delivered: 0.0, collected: 0.0, capacity: nil)
      bucket[:delivery] += unit[:delivery].to_f
      bucket[:pickup] += unit[:pickup].to_f
      bucket[:delivered] += unit[:delivered].to_f
      bucket[:collected] += unit[:collected].to_f
      bucket[:capacity] = bucket[:capacity].to_f + unit[:capacity].to_f if unit[:capacity].present?
    end
    grouped.values
  end
  private :plan_totals, :snapshot_number, :snapshot_cost, :merged_units

  def progress_counts
    stops = operation_stops.joins(:operation_route)
                          .merge(OperationRoute.planned)
                          .executable
                          .where.not(kind: 'rest')
    total = stops.count
    treated = stops.where(status: OperationStop::TREATED_STATUSES).count
    { treated: treated, total: total }
  end
end
