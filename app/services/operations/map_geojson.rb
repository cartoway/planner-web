# frozen_string_literal: true

module Operations
  class MapGeojson
    OPACITY_MIN = 0.4
    OPACITY_MAX = 1.0

    def self.call(operation:, routes:)
      new(operation, routes).call
    end

    def initialize(operation, routes)
      @operation = operation
      @routes = routes
    end

    def call
      features = @routes.flat_map { |route| route_features(route) + [positions_feature(route)] }.compact
      paint_depot_returns(features)
      { type: 'FeatureCollection', features: features }
    end

    private

    def route_features(route)
      counts = route.progress_counts
      props = {
        operation_route_id: route.id,
        name: route.vehicle_name,
        color: route.vehicle_color,
        progress: counts[:progress],
        treated_count: counts[:treated],
        total_count: counts[:total]
      }
      points = route.operation_stops.select { |stop| stop.sync_state == 'active' && stop.active != false }.sort_by(&:index).filter_map { |stop| point_feature(stop, props) }
      lines = track_features(route, props, counts[:progress].to_f)
      [*lines, *points, *depot_features(route, props)].compact
    end

    def depot_features(route, props)
      route.list_depots.each_with_index.filter_map do |depot, index|
        next if depot.blank? || depot[:lat].blank? || depot[:lng].blank?

        role = index.zero? ? 'start' : 'end'
        # No end store on the snapshot: this route has no return to wait for.
        next if role == 'end' && route.vehicle_usage_snapshot['store_stop'].blank?

        {
          type: 'Feature',
          geometry: { type: 'Point', coordinates: [depot[:lng].to_f, depot[:lat].to_f] },
          properties: props.except(:color).merge(
            label: depot[:name],
            kind: 'depot',
            depot_role: role,
            status: depot[:status],
            returns_complete: false,
            treated: false,
            opacity: OPACITY_MAX
          )
        }
      end
    end

    # A place turns complete when every existing end depot there is finished.
    # A depot is never delivered. Routes without an end depot are not part of that check.
    def paint_depot_returns(features)
      depots = features.select { |feature| feature.dig(:properties, :kind) == 'depot' }
      complete = depots.select { |feature| feature.dig(:properties, :depot_role) == 'end' }
                       .group_by { |feature| depot_key(feature) }
      complete.each do |key, ends|
        done = ends.all? { |feature| feature.dig(:properties, :status).to_s.downcase == 'finished' }
        next unless done

        depots.each do |feature|
          feature[:properties][:returns_complete] = true if depot_key(feature) == key
        end
      end
    end

    def depot_key(feature)
      lng, lat = feature[:geometry][:coordinates]
      [lng.to_f.round(5), lat.to_f.round(5)]
    end

    def point_feature(stop, props)
      lat = stop.destination_snapshot['lat'] || stop.store_snapshot['lat']
      lng = stop.destination_snapshot['lng'] || stop.store_snapshot['lng']
      return nil if lat.blank? || lng.blank?

      treated = OperationStop::TREATED_STATUSES.include?(stop.status.to_s.downcase)
      {
        type: 'Feature',
        geometry: { type: 'Point', coordinates: [lng.to_f, lat.to_f] },
        properties: props.merge(
          operation_stop_id: stop.id,
          label: stop.address_label,
          kind: stop.kind,
          index: stop.index,
          phase: stop.phase,
          treated: treated,
          opacity: treated ? OPACITY_MIN : OPACITY_MAX
        )
      }
    end

    def track_features(route, props, progress)
      tracks = route.route_snapshot['tracks']
      if tracks.blank? && route.route
        tracks = Snapshots.tracks_for(route.route)
      end
      parts = Array(tracks).filter_map { |track|
        coords = coordinates_for(track)
        coords if coords.size >= 2
      }
      return [] if parts.empty?

      # Finished stops fade the prefix of the planned line; the rest stays solid.
      fade_parts(parts, progress).map { |coords, opacity| line_feature(coords, props, opacity) }
    end

    def fade_parts(parts, progress)
      return parts.map { |coords| [coords, OPACITY_MAX] } if progress <= 0
      return parts.map { |coords| [coords, OPACITY_MIN] } if progress >= 1

      lengths = parts.map { |coords| length_of(coords) }
      total = lengths.sum
      return parts.map { |coords| [coords, OPACITY_MAX] } if total <= 0

      cut = total * progress
      walked = 0.0
      parts.each_with_index.flat_map { |coords, index|
        part_length = lengths[index]
        if walked + part_length <= cut
          walked += part_length
          [[coords, OPACITY_MIN]]
        elsif walked >= cut
          [[coords, OPACITY_MAX]]
        else
          done, rest = split_at(coords, cut - walked)
          walked += part_length
          [[done, OPACITY_MIN], [rest, OPACITY_MAX]].select { |piece, _| piece.size >= 2 }
        end
      }
    end

    def line_feature(coords, props, opacity)
      {
        type: 'Feature',
        geometry: { type: 'LineString', coordinates: coords },
        properties: props.merge(geometry_kind: 'route', opacity: opacity.round(3))
      }
    end

    def length_of(coords)
      coords.each_cons(2).sum { |start, finish| Math.hypot(finish[0] - start[0], finish[1] - start[1]) }
    end

    def split_at(coords, distance)
      done = [coords.first]
      rest = nil
      coords.each_cons(2).with_index do |(start, finish), index|
        if rest
          rest << finish
          next
        end

        segment = Math.hypot(finish[0] - start[0], finish[1] - start[1])
        if segment <= distance
          done << finish
          distance -= segment
        else
          ratio = segment.zero? ? 0 : distance / segment
          middle = [start[0] + ((finish[0] - start[0]) * ratio), start[1] + ((finish[1] - start[1]) * ratio)]
          done << middle
          rest = [middle, finish, *coords[(index + 2)..]]
        end
      end
      [done, rest || [coords.last]]
    end

    def coordinates_for(track)
      track = track.stringify_keys
      if track['coordinates'].present?
        return track['coordinates']
      end
      return [] if track['polylines'].blank?

      # FastPolylines is [lat, lng]; GeoJSON is [lng, lat].
      FastPolylines.decode(track['polylines'], 6).map { |lat, lng| [lng.to_f, lat.to_f] }
    end

    def positions_feature(route)
      coords = route.vehicle_positions.order(:positioned_at).pluck(:lng, :lat)
      return nil if coords.size < 2

      {
        type: 'Feature',
        geometry: { type: 'LineString', coordinates: coords },
        properties: { operation_route_id: route.id, geometry_kind: 'positions', color: '#111111' }
      }
    end
  end
end
