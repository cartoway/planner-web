# frozen_string_literal: true

module DeliverDemo
  # Advances demo vehicles along snapshot tracks and writes positions/statuses.
  # Wall-clock ticks stay compressed; recorded timestamps follow planned schedule.
  class Tick
    STEPS_PER_LEG = 6
    MAX_SERVICE_SECONDS = 5 * 60
    DEFAULT_SERVICE_SECONDS = 2 * 60
    JITTER_SECONDS = 5 * 60
    FALLBACK_START_SECONDS = 8 * 3600
    FALLBACK_END_SECONDS = 18 * 3600

    def self.call(operation:, cursors: {})
      new(operation, cursors).call
    end

    def initialize(operation, cursors)
      @operation = operation
      @cursors = (cursors || {}).stringify_keys
    end

    # Returns [cursors_hash, done]
    def call
      # Delayed Job has no user around_action: force the customer TZ so planned seconds
      # (local wall-clock) are not written as UTC (+1h/+2h drift in the UI).
      Time.use_zone(zone_for(@operation)) { run }
    end

    private

    def run
      return [{}, true] unless @operation.open?

      done_all = true
      next_cursors = {}
      @operation.operation_routes.planned.includes(:operation_stops).find_each do |route|
        cursor = (@cursors[route.id.to_s] || {}).stringify_keys
        updated, route_done = tick_route(route, cursor)
        next_cursors[route.id.to_s] = updated
        done_all &&= route_done
      end
      [next_cursors, done_all]
    end

    def zone_for(operation)
      user = operation.customer.users.order(:id).first
      zone = user&.time_zone.presence
      zone = I18n.t('default_time_zone', locale: user&.locale.presence || I18n.default_locale) if zone.blank? || zone == 'UTC'
      zone
    end

    def tick_route(route, cursor)
      stops = route.operation_stops.executable.order(:index).to_a
      legs = legs_for(route, stops)
      return [cursor.merge('done' => true), true] if stops.empty? || legs.empty?
      return [cursor, true] if cursor['done']

      cursor = ensure_departure!(route, cursor)
      stop_index = cursor['stop_index'].to_i
      stop = stops[stop_index]
      return finish_route!(route, cursor, legs, stops) unless stop

      leg = legs[stop_index] || []
      # Zero-length (or missing) drive: treat the stop and chain to the next tick step now.
      return complete_zero_leg!(route, cursor, legs, stops, stop_index, leg) if zero_length_path?(leg)

      cursor = ensure_offset!(cursor, route, stops, stop_index)
      phase = cursor['phase'].presence || 'drive'
      step = cursor['step'].to_i

      if phase == 'drive' && !cursor['intransit']
        record_intransit!(stop, stops, stop_index, route, cursor)
        cursor = cursor.merge('intransit' => true)
      end

      if phase == 'service'
        record_position!(route, leg, 1.0, stops, stop_index, cursor)
        record_stop_finish!(stop, stops, stop_index, cursor)
        return advance_after_stop(route, cursor, legs, stops, stop_index)
      end

      step += 1
      ratio = (step.to_f / STEPS_PER_LEG).clamp(0.0, 1.0)
      record_position!(route, leg, ratio, stops, stop_index, cursor)

      if step >= STEPS_PER_LEG
        record_stop_arrival!(stop, stops, stop_index, cursor)
        # Visits go straight to treated; store/rest keep a short on-site phase.
        if stop.kind == 'visit'
          record_stop_finish!(stop, stops, stop_index, cursor)
          return advance_after_stop(
            route,
            cursor.merge('step' => step, 'intransit' => true),
            legs,
            stops,
            stop_index
          )
        end

        return [
          cursor.merge('phase' => 'service', 'step' => step, 'intransit' => true),
          false
        ]
      end

      [cursor.merge('phase' => 'drive', 'step' => step, 'intransit' => true), false]
    end

    # Instantly arrive/finish a stop with no drive distance, then continue this wall-clock tick.
    def complete_zero_leg!(route, cursor, legs, stops, stop_index, leg)
      stop = stops[stop_index]
      cursor = ensure_offset!(cursor, route, stops, stop_index)
      unless cursor['intransit']
        record_intransit!(stop, stops, stop_index, route, cursor)
        cursor = cursor.merge('intransit' => true)
      end
      record_position!(route, leg, 1.0, stops, stop_index, cursor) if leg.size >= 2
      record_stop_arrival!(stop, stops, stop_index, cursor)
      record_stop_finish!(stop, stops, stop_index, cursor)
      next_cursor, done = advance_after_stop(
        route,
        cursor.merge('step' => STEPS_PER_LEG, 'intransit' => true),
        legs,
        stops,
        stop_index
      )
      return [next_cursor, done] if done

      tick_route(route, next_cursor)
    end

    def zero_length_path?(path)
      return true if path.blank? || path.size < 2

      origin = path.first
      # ~1m; duplicate stop coords / empty router legs collapse to one wall-clock tick.
      path.all? { |lng, lat|
        (lng.to_f - origin[0]).abs <= 1e-5 && (lat.to_f - origin[1]).abs <= 1e-5
      }
    end

    def advance_after_stop(route, cursor, legs, stops, stop_index)
      next_index = stop_index + 1
      if next_index >= stops.size
        return finish_route!(route, cursor.merge('stop_index' => next_index, 'step' => 0), legs, stops)
      end

      [
        cursor.merge(
          'phase' => 'drive',
          'stop_index' => next_index,
          'step' => 0,
          'intransit' => false
        ),
        false
      ]
    end

    def ensure_departure!(route, cursor)
      return cursor if cursor['departed']

      at = planned_time(route.route_snapshot['start']) || planned_time(FALLBACK_START_SECONDS)
      route.update!(
        departure_status: 'finished',
        departure_status_updated_at: at
      )
      cursor.merge('departed' => true, 'stop_index' => 0, 'step' => 0, 'phase' => 'drive')
    end

    def finish_route!(route, cursor, legs, stops)
      last_leg = legs[[stops.size - 1, 0].max] || []
      record_position!(route, last_leg, 1.0, stops, [stops.size - 1, 0].max, cursor) if last_leg.size >= 2
      at = planned_time(route.route_snapshot['end']) || planned_time(FALLBACK_END_SECONDS)
      route.update!(arrival_status: 'finished', arrival_status_updated_at: at) if route.arrival_status != 'finished'
      [cursor.merge('done' => true, 'phase' => 'done'), true]
    end

    def record_position!(route, leg, ratio, stops, stop_index, cursor)
      lat, lng = point_on_path(leg, ratio)
      return if lat.nil?

      VehiclePositions::Record.call(
        operation_route: route,
        lat: lat,
        lng: lng,
        positioned_at: position_time(route, stops, stop_index, ratio, cursor),
        source: 'demo',
        payload: { 'demo' => true }
      )
    rescue VehiclePositions::Record::OperationNotOpen
      nil
    end

    def record_intransit!(stop, stops, stop_index, route, cursor)
      return if stop.kind == 'rest'
      return if stop.status.present? && !%w[planned].include?(stop.status.to_s.downcase)

      desired = leg_start_time(route, stops, stop_index, cursor)
      OperationStops::RecordStatus.call(
        operation_stop: stop,
        status: 'intransit',
        recorded_at: monotonic_recorded_at(stop, desired),
        eta: actual_arrival(stop, offset_seconds(cursor, stop_index)),
        source: 'demo'
      )
    end

    def record_stop_arrival!(stop, stops, stop_index, cursor)
      return if stop.kind == 'visit' # visit: intransit → finished/delivered, no on-site status
      return if OperationStop::TREATED_STATUSES.include?(stop.status.to_s.downcase)

      status = stop.kind == 'store' ? 'atstore' : 'started'
      desired = actual_arrival(stop, offset_seconds(cursor, stop_index))
      OperationStops::RecordStatus.call(
        operation_stop: stop,
        status: status,
        recorded_at: monotonic_recorded_at(stop, desired),
        eta: next_eta(stops, stop_index, cursor),
        source: 'demo'
      )
    end

    def record_stop_finish!(stop, stops, stop_index, cursor)
      return if OperationStop::TREATED_STATUSES.include?(stop.status.to_s.downcase)

      desired = actual_finish(stop, offset_seconds(cursor, stop_index))
      OperationStops::RecordStatus.call(
        operation_stop: stop,
        status: finish_status_for(stop),
        recorded_at: monotonic_recorded_at(stop, desired),
        eta: next_eta(stops, stop_index, cursor),
        source: 'demo'
      )
    end

    # RecordStatus ignores events older than status_updated_at — keep demo times moving forward
    # when planned legs overlap (service + jitter can push the next leg_start past the next plan).
    def monotonic_recorded_at(stop, desired)
      previous = stop.status_updated_at
      return desired if previous.blank? || desired >= previous

      previous + 1.second
    end

    def finish_status_for(stop)
      stop.kind == 'visit' ? 'delivered' : 'finished'
    end

    def next_eta(stops, stop_index, cursor)
      nxt = stops[stop_index + 1]
      return if nxt.blank?

      ensure_offset!(cursor, nxt.operation_route, stops, stop_index + 1)
      actual_arrival(nxt, offset_seconds(cursor, stop_index + 1))
    end

    def planned_arrival(stop)
      stop.planned_at || interpolate_stop_time(stop)
    end

    def actual_arrival(stop, offset_seconds)
      planned_arrival(stop) + offset_seconds.seconds
    end

    def actual_finish(stop, offset_seconds)
      actual_arrival(stop, offset_seconds) + service_seconds(stop)
    end

    def service_seconds(stop)
      seconds = stop.visit_snapshot&.[]('duration') ||
                stop.destination_snapshot&.[]('duration') ||
                stop.store_snapshot&.[]('duration')
      seconds = seconds.to_i if seconds.present?
      seconds = DEFAULT_SERVICE_SECONDS if seconds.blank? || seconds <= 0
      [seconds, MAX_SERVICE_SECONDS].min.seconds
    end

    def ensure_offset!(cursor, route, stops, stop_index)
      offsets = (cursor['offsets'] || {}).stringify_keys
      key = stop_index.to_s
      offsets[key] = sample_offset_seconds(route, stops, stop_index) unless offsets.key?(key)
      cursor['offsets'] = offsets
      cursor
    end

    def offset_seconds(cursor, stop_index)
      (cursor.dig('offsets', stop_index.to_s) || 0).to_i
    end

    # Random ±5 min vs plan. Early (negative) cannot exceed the planned leg duration.
    def sample_offset_seconds(route, stops, stop_index)
      raw = random_jitter_seconds
      return raw unless raw.negative?

      leg = planned_leg_seconds(route, stops, stop_index)
      return 0 if leg <= 0

      [raw, -leg].max
    end

    def random_jitter_seconds
      rand(-JITTER_SECONDS..JITTER_SECONDS)
    end

    def planned_leg_seconds(route, stops, stop_index)
      start_at = if stop_index <= 0
        planned_time(route.route_snapshot['start']) || planned_time(FALLBACK_START_SECONDS)
      else
        planned_arrival(stops[stop_index - 1]) + service_seconds(stops[stop_index - 1])
      end
      end_at = planned_arrival(stops[stop_index])
      [(end_at - start_at).to_i, 0].max
    end

    def leg_start_time(route, stops, stop_index, cursor)
      if stop_index <= 0
        planned_time(route.route_snapshot['start']) || planned_time(FALLBACK_START_SECONDS)
      else
        actual_finish(stops[stop_index - 1], offset_seconds(cursor, stop_index - 1))
      end
    end

    def interpolate_stop_time(stop)
      route = stop.operation_route
      stops = route.operation_stops.executable.order(:index).to_a
      index = stops.index(stop) || 0
      start_at = planned_time(route.route_snapshot['start']) || planned_time(FALLBACK_START_SECONDS)
      end_at = planned_time(route.route_snapshot['end']) || planned_time(FALLBACK_END_SECONDS)
      return start_at if stops.size <= 1

      fraction = (index + 1).to_f / stops.size
      start_at + ((end_at - start_at) * fraction)
    end

    def position_time(route, stops, stop_index, ratio, cursor)
      prev_at = leg_start_time(route, stops, stop_index, cursor)
      nxt = stops[stop_index] || stops.last
      next_at = actual_arrival(nxt, offset_seconds(cursor, stop_index))
      prev_at + ((next_at - prev_at) * ratio.to_f.clamp(0.0, 1.0))
    end

    def planned_time(seconds)
      Operations::Snapshots.timestamp_on(@operation.date, seconds)
    end

    # One multipolyline path per stop (leg ending at that stop), keyed by stop.index.
    def legs_for(route, stops)
      tracks = Array(route.route_snapshot['tracks'])
      by_stop_index = Hash.new { |hash, key| hash[key] = [] }
      unordered = []

      tracks.each do |track|
        coords = coordinates_for(track)
        next if coords.size < 2

        indices = Array(track['stop_indices'] || track['stop_index']).compact.map(&:to_i)
        if indices.any?
          indices.each { |index| by_stop_index[index] << coords }
        else
          unordered << coords
        end
      end

      stops.map.with_index { |stop, position|
        parts = by_stop_index[stop.index.to_i]
        parts = [unordered[position]].compact if parts.empty?
        path = concat_segments(parts)
        path.size >= 2 ? path : fallback_leg(route, stops, position)
      }
    end

    def concat_segments(parts)
      parts.reduce([]) { |path, segment|
        next path if segment.blank?
        next segment if path.empty?
        next path + segment[1..] if path.last == segment.first

        path + segment
      }
    end

    def fallback_leg(route, stops, position)
      from =
        if position <= 0
          store = route.vehicle_usage_snapshot&.[]('store_start')
          [store['lng'].to_f, store['lat'].to_f] if store&.[]('lat') && store['lng']
        else
          prev = stops[position - 1]
          [prev.lng.to_f, prev.lat.to_f] if prev&.lat && prev.lng
        end
      to_stop = stops[position]
      to = [to_stop.lng.to_f, to_stop.lat.to_f] if to_stop&.lat && to_stop.lng
      return [] unless from && to

      [from, to]
    end

    def coordinates_for(track)
      track = track.stringify_keys
      if track['coordinates'].present?
        coords = track['coordinates']
        # MultiLineString: [[[lng,lat],...], ...] — flatten into one leg path.
        if coords.first.is_a?(Array) && coords.first.first.is_a?(Array)
          return concat_segments(coords.map { |line| line.map { |lng, lat| [lng.to_f, lat.to_f] } })
        end

        return coords.map { |lng, lat| [lng.to_f, lat.to_f] }
      end
      return [] if track['polylines'].blank?

      # One encoded string, or several encodings for a multipolyline leg.
      # Array(string) splits characters — wrap scalars explicitly.
      encodings = track['polylines'].is_a?(Array) ? track['polylines'] : [track['polylines']]
      segments = encodings.map { |encoded|
        FastPolylines.decode(encoded, 6).map { |lat, lng| [lng.to_f, lat.to_f] }
      }
      concat_segments(segments)
    end

    # Path vertices are [lng, lat]; returns [lat, lng] for VehiclePositions::Record.
    # ratio is local to the current stop-to-stop multipolyline (0..1).
    def point_on_path(path, ratio)
      return if path.blank? || path.size < 2
      return [path.first[1], path.first[0]] if ratio <= 0
      return [path.last[1], path.last[0]] if ratio >= 1

      max = path.size - 1
      pos = ratio.to_f * max
      i = pos.floor
      t = pos - i
      a = path[i]
      b = path[[i + 1, max].min]
      lng = a[0] + ((b[0] - a[0]) * t)
      lat = a[1] + ((b[1] - a[1]) * t)
      [lat, lng]
    end
  end
end
