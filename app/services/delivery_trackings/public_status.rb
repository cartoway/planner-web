# frozen_string_literal: true

module DeliveryTrackings
  class PublicStatus
    include ApplicationHelper

    JITTER_METERS = 300
    DEPOT_LOADING_CODES = %w[atstore inprocessing].freeze
    PAST_DEPOT_STATUSES = (%w[intransit started] + OperationStop::TREATED_STATUSES).freeze

    VisitView = Struct.new(
      :stop, :chip, :chip_key, :eta_window, :timeline, :stops_before, :terminal, :ref, :map_data,
      keyword_init: true
    )

    def initialize(tracking)
      @tracking = tracking
      @customer = tracking.operation.customer
      @stops = tracking.visit_stops.to_a
      @route_stops = {}
    end

    def shipper_name
      @customer.company_name.presence || @customer.name
    end

    def shipper_logo_url
      @customer.company_logo.url.presence
    end

    def last_updated_at
      [
        *@stops.filter_map(&:status_updated_at),
        *@stops.filter_map { |s| s.operation_route.departure_status_updated_at },
        *@stops.filter_map { |s| preceding_store(s)&.status_updated_at }
      ].compact.max
    end

    def visits
      @stops.map { |stop| build_visit(stop) }
    end

    def current_visit
      open = visits.reject(&:terminal)
      open.first || visits.last
    end

    def expired?
      @tracking.expired?
    end

    private

    def build_visit(stop)
      route = stop.operation_route
      chip_key = chip_for(stop, route)
      stops_before = upstream_count(stop)
      VisitView.new(
        stop: stop,
        chip: I18n.t("delivery_trackings.chips.#{chip_key}"),
        chip_key: chip_key,
        eta_window: eta_window_for(stop, chip_key),
        timeline: timeline_for(stop, route, stops_before, chip_key),
        stops_before: stops_before,
        terminal: %w[delivered failed missed exception].include?(chip_key),
        ref: stop.visit_snapshot&.[]('ref').presence || stop.destination_snapshot&.[]('ref'),
        map_data: map_payload(stop, route, chip_key, stops_before)
      )
    end

    def chip_for(stop, route)
      code = stop.status.to_s.downcase
      return 'failed' if OperationStop::FAILED_STATUSES.include?(code)
      return 'exception' if OperationStop::EXCEPTION_STATUSES.include?(code)
      return 'delivered' if OperationStop::DONE_STATUSES.include?(code)
      return 'missed' if missed_delivery?(stop, route)
      return 'intransit' if code == 'intransit'
      # "started" = on-site; public chip stays departed/planned — only intransit is "en route".

      depot = depot_leg(stop, route)
      return 'loading' if depot[:loading] && !depot[:departed]
      return 'departed' if depot[:departed]

      'planned'
    end

    def eta_window_for(operation_stop, chip_key = nil)
      chip_key ||= chip_for(operation_stop, operation_stop.operation_route)
      return if %w[delivered failed exception].include?(chip_key)
      return I18n.t('delivery_trackings.show.undelivered') if chip_key == 'missed'

      bounds = eta_bounds(operation_stop)
      return unless bounds

      from, to = bounds
      return format_window(from, to) if Time.current <= to
      return I18n.t('delivery_trackings.show.imminent') unless route_finished?(operation_stop.operation_route)

      I18n.t('delivery_trackings.show.undelivered')
    end

    def eta_bounds(operation_stop)
      center = public_eta(operation_stop)
      return unless center

      before = @customer.delivery_tracking_eta_gap_before.to_i
      after = @customer.delivery_tracking_eta_gap_after.to_i
      [
        round_time_to_nearest_quarter(center - before.minutes),
        round_time_to_nearest_quarter(center + after.minutes)
      ]
    end

    def eta_max_exceeded?(operation_stop)
      bounds = eta_bounds(operation_stop)
      return false unless bounds

      Time.current > bounds.last
    end

    def route_finished?(route)
      route.arrival_status.to_s.downcase == 'finished'
    end

    # End depot finished and this visit was never delivered/failed on the OperationStop.
    def missed_delivery?(operation_stop, route)
      code = operation_stop.status.to_s.downcase
      return false if OperationStop::FAILED_STATUSES.include?(code)
      return false if OperationStop::DONE_STATUSES.include?(code)

      route_finished?(route)
    end

    # Centre ETA from OperationStop only (never .eta): planned_at shifted by last treated stop / depot delay.
    def public_eta(operation_stop)
      planned = operation_stop.planned_at
      return unless planned

      planned + segment_delay(operation_stop)
    end

    def segment_delay(operation_stop)
      route = operation_stop.operation_route
      store = preceding_store(operation_stop)
      segment_start = store&.index || -1
      prior = route_stops(route).select do |s|
        s.index > segment_start &&
          s.index < operation_stop.index &&
          OperationStop::TREATED_STATUSES.include?(s.status.to_s.downcase)
      end
      reference = prior.reverse.find { |s| s.planned_at.present? && s.status_updated_at.present? }
      return reference.status_updated_at - reference.planned_at if reference

      depot_delay(route, store)
    end

    # Start depot lives on OperationRoute; mid-route reload is an OperationStop kind=store.
    def depot_delay(route, store)
      if store
        return 0 if store.status.blank?

        planned = store.planned_at
        actual = store.status_updated_at
      else
        return 0 if route.departure_status.blank?

        planned = depot_planned_at(route)
        actual = route.departure_status_updated_at
      end
      return 0 if planned.blank? || actual.blank?

      actual - planned
    end

    def depot_planned_at(route)
      seconds = route.route_snapshot&.[]('start').presence ||
                route.route_snapshot&.[]('departure').presence ||
                route.vehicle_usage_snapshot&.[]('time_window_start')
      Operations::Snapshots.timestamp_on(route.operation.date, seconds)
    end

    def format_window(from, to)
      "#{I18n.l(from, format: :hour_minute)} – #{I18n.l(to, format: :hour_minute)}"
    rescue StandardError
      nil
    end

    def timeline_for(stop, route, stops_before, chip_key)
      depot = depot_leg(stop, route)
      items = []
      items << step(
        'loading',
        done: depot[:loading],
        current: chip_key == 'loading',
        at: depot[:loading_at]
      )
      items << step(
        'departed',
        done: depot[:departed],
        current: false,
        at: depot[:departed_at]
      )
      if stops_before.positive? && !%w[delivered failed missed exception].include?(chip_key)
        # After depot departure, focus on remaining upstream stops — not intransit yet.
        upstream_current = depot[:departed] && %w[departed intransit].include?(chip_key)
        items << {
          key: 'upstream',
          label: I18n.t('delivery_trackings.timeline.upstream', count: stops_before),
          detail: I18n.t('delivery_trackings.timeline.upstream_detail'),
          state: upstream_current ? 'current' : 'info'
        }
      end
      unless %w[delivered failed missed exception].include?(chip_key)
        overdue = eta_max_exceeded?(stop)
        intransit_current = stops_before.zero? && %w[departed intransit].include?(chip_key)
        intransit_eta = if intransit_current && !overdue
                          bounds = eta_bounds(stop)
                          bounds && format_window(*bounds)
                        end
        items << step(
          'intransit',
          done: false,
          current: intransit_current,
          at: status_event_at(stop, 'intransit', 'started'),
          eta: intransit_eta,
          detail: (overdue ? I18n.t('delivery_trackings.show.imminent') : nil)
        )
      end
      items << terminal_timeline_step(stop, chip_key)

      # Missed tour: incomplete non-depot steps get the undelivered message (depot lines stay as-is).
      apply_missed_timeline!(items) if chip_key == 'missed'
      items
    end

    def terminal_timeline_step(stop, chip_key)
      at = status_event_at(stop, *OperationStop::TREATED_STATUSES) ||
           (%w[delivered failed exception].include?(chip_key) ? stop.status_updated_at : nil)

      case chip_key
      when 'delivered'
        {
          key: 'delivered',
          label: I18n.t('delivery_trackings.timeline.delivered'),
          detail: format_step_time(at).presence || I18n.t('delivery_trackings.timeline.delivered_detail'),
          state: 'done'
        }
      when 'failed'
        {
          key: 'failed',
          label: I18n.t('delivery_trackings.timeline.failed'),
          detail: I18n.t('delivery_trackings.timeline.failed_detail'),
          state: 'failed'
        }
      when 'exception'
        {
          key: 'exception',
          label: I18n.t('delivery_trackings.timeline.exception'),
          detail: I18n.t('delivery_trackings.timeline.exception_detail'),
          state: 'alert'
        }
      when 'missed'
        {
          key: 'failed',
          label: I18n.t('delivery_trackings.timeline.failed'),
          detail: I18n.t('delivery_trackings.show.undelivered'),
          state: 'failed'
        }
      else
        step('delivered')
      end
    end

    def apply_missed_timeline!(items)
      message = I18n.t('delivery_trackings.show.undelivered')
      items.each do |item|
        next if item[:state] == 'done'
        next if %w[loading departed].include?(item[:key])

        item[:state] = 'failed'
        item[:detail] = message
      end
    end

    def step(key, done: false, current: false, at: nil, eta: nil, detail: nil)
      state = current ? 'current' : (done ? 'done' : 'pending')
      {
        key: key,
        label: I18n.t("delivery_trackings.timeline.#{key}"),
        detail: detail.presence || step_detail(state, at: at, eta: eta),
        state: state
      }
    end

    def step_detail(state, at: nil, eta: nil)
      case state
      when 'done'
        format_step_time(at)
      when 'current'
        if eta.present?
          I18n.t('delivery_trackings.timeline.in_progress_eta', eta: eta)
        else
          I18n.t('delivery_trackings.timeline.in_progress')
        end
      else
        I18n.t('delivery_trackings.timeline.upcoming')
      end
    end

    def format_step_time(time)
      return unless time

      if time.to_date == Time.zone.today
        I18n.t('delivery_trackings.timeline.today_at', time: I18n.l(time, format: :hour_minute))
      else
        I18n.l(time, format: :short)
      end
    rescue StandardError
      nil
    end

    # Depot leg shared by all visits until the next store stop (start route or mid-route reload).
    # "Départ dépôt" is done only when that depot status is finished ("Terminé").
    def depot_leg(stop, route)
      store = preceding_store(stop)
      if store
        code = store.status.to_s.downcase
        departed = code == 'finished'
        loading = DEPOT_LOADING_CODES.include?(code) || departed
        departed_at = status_event_at(store, 'finished') || (departed ? store.status_updated_at : nil)
        loading_at = status_event_at(store, *DEPOT_LOADING_CODES) ||
                     (DEPOT_LOADING_CODES.include?(code) ? store.status_updated_at : nil) ||
                     (departed ? departed_at : nil)
        # Visit already past this depot ⇒ show depot steps done even if store cursor lagged.
        if !departed && past_depot?(stop)
          departed = true
          loading = true
          departed_at ||= store.status_updated_at || stop.status_updated_at
          loading_at ||= departed_at
        end
      else
        dep = route.departure_status.to_s.downcase
        departed = dep == 'finished'
        loading = DEPOT_LOADING_CODES.include?(dep) || departed
        departed_at = departed ? route.departure_status_updated_at : nil
        loading_at = if DEPOT_LOADING_CODES.include?(dep)
                       route.departure_status_updated_at
                     else
                       stashed_departure_loading_at(route) || (departed ? departed_at : nil)
                     end
        # Visit already past start depot ⇒ treat departure as done (cursor may still be blank).
        if !departed && past_depot?(stop)
          departed = true
          loading = true
          departed_at ||= route.departure_status_updated_at || stop.status_updated_at
          loading_at ||= stashed_departure_loading_at(route) || departed_at
        end
      end
      {
        loading: loading,
        departed: departed,
        loading_at: loading_at,
        departed_at: departed_at
      }
    end

    def past_depot?(stop)
      PAST_DEPOT_STATUSES.include?(stop.status.to_s.downcase)
    end

    def stashed_departure_loading_at(route)
      raw = route.custom_attributes.is_a?(Hash) && route.custom_attributes['_departure_loading_at']
      return if raw.blank?

      Time.zone.parse(raw.to_s)
    rescue ArgumentError, TypeError
      nil
    end

    # Last reload/store stop before this visit; nil → use route start departure_status.
    def preceding_store(stop)
      route_stops(stop.operation_route)
        .select { |s| s.kind == 'store' && s.index < stop.index }
        .max_by(&:index)
    end

    def route_stops(route)
      @route_stops[route.id] ||= route.operation_stops.executable.includes(:operation_stop_status_events).order(:index).to_a
    end

    def status_event_at(stop, *codes)
      wanted = codes.map { |c| c.to_s.downcase }
      stop.operation_stop_status_events
          .select { |event| wanted.include?(event.status.to_s.downcase) }
          .map(&:recorded_at)
          .compact
          .max
    end

    def upstream_count(stop)
      segment_start = preceding_store(stop)&.index || -1
      route_stops(stop.operation_route).count do |s|
        s.kind == 'visit' &&
          s.index > segment_start &&
          s.index < stop.index &&
          !OperationStop::TREATED_STATUSES.include?(s.status.to_s.downcase)
      end
    end

    def map_payload(stop, route, chip_key, stops_before)
      lat = stop.lat
      lng = stop.lng
      show_live = %w[departed intransit].include?(chip_key) && lat.present? && lng.present?
      vehicle = show_live ? jittered_position(route.latest_position) : nil
      {
        destination: (lat.present? && lng.present? ? { lat: lat, lng: lng } : nil),
        vehicle: vehicle,
        stops_before: stops_before,
        show_live: show_live,
        track: show_live ? remaining_track(route) : [],
        map_layers: default_map_layers
      }
    end

    # Same default as User#assign_defaults_layer: first non-overlay profile layer.
    def default_map_layers
      @default_map_layers ||= begin
        layer = @customer.profile.layers.order(:id).find_by(overlay: false)
        if layer
          entry = {
            name: layer.translated_name,
            url: layer.url,
            vector_style_url: layer.vector_style_url,
            attribution: layer.map_attribution,
            default: true,
            overlay: false
          }
          { entry[:name] => entry }
        else
          {}
        end
      end
    end

    def jittered_position(position)
      return unless position&.lat && position.lng

      seed = Zlib.crc32("#{position.id}-#{position.lat}-#{position.lng}")
      rng = Random.new(seed)
      angle = rng.rand * 2 * Math::PI
      dist = JITTER_METERS * (0.4 + rng.rand * 0.6)
      dlat = (dist * Math.cos(angle)) / 111_320.0
      dlng = (dist * Math.sin(angle)) / (111_320.0 * Math.cos(position.lat * Math::PI / 180.0))
      { lat: position.lat + dlat, lng: position.lng + dlng }
    end

    def remaining_track(route)
      tracks = route.route_snapshot&.[]('tracks')
      return [] unless tracks.is_a?(Array)

      tracks.flat_map { |t| Array(t['coordinates']) }.select { |c| c.is_a?(Array) && c.size >= 2 }
    end
  end
end
