# frozen_string_literal: true

require 'csv'
require 'zip'
require 'json'

module Operations
  # Spreadsheet + ZIP archive (HTML report, CSV, proofs, delivery notes, tracks) for one operation.
  class Export
    CSV_HEADERS = %w[
      operation_date operation_ref operation_name operation_status
      operation_delivered operation_failed operation_exception operation_total operation_delay_min
      route_index route_ref vehicle_name driver_email driver_phone
      route_delivered route_failed route_exception route_total route_distance_m route_drive_time_s route_duration_s
      stop_index stop_kind stop_status destination_ref visit_ref name street postalcode city country phone email detail comment
      lat lng
      planned_arrival planned_departure actual_arrival actual_departure delay_minutes time_windows
      stop_distance_m stop_drive_time_s stop_wait_time_s
      note quantities photos signature delivery_note track_file
    ].freeze
    # ponytail: bounded WeasyPrint pool; raise EXPORT_PDF_POOL_SIZE if export hosts have spare CPU.
    PDF_POOL_SIZE = (ENV['EXPORT_PDF_POOL_SIZE'].presence || 3).to_i

    def initialize(operation)
      @operation = operation
      @routes = preload_routes
      @operation_board = @operation.board(routes: @routes)
    end

    def basename
      parts = ['operation', @operation.ref.presence || @operation.id, @operation.date]
      parts.compact.join('_').tr('/', '-').delete('"')
    end

    def to_csv(excel: false, media_paths: {}, track_paths: {})
      options = excel ? { col_sep: ';', row_sep: "\r\n" } : {}
      body = CSV.generate(**options) do |csv|
        csv << CSV_HEADERS
        each_stop do |route, stop|
          csv << row_for(route, stop, media_paths[stop.id] || {}, track_paths[route.id])
        end
      end
      return body unless excel

      body.encode(I18n.t('encoding'), invalid: :replace, undef: :replace, replace: '')
    end

    def to_zip
      media_paths = {}
      track_paths = {}
      pending_notes = []
      Zip::OutputStream.write_buffer do |zio|
        @routes.each do |route|
          rel = pack_route_track!(zio, route)
          track_paths[route.id] = rel if rel
        end

        each_stop do |route, stop|
          paths = pack_stop_media!(zio, route, stop)
          if stop.delivery_note_exportable?
            pending_notes << stop
            paths[:delivery_note] = "delivery_notes/stop_#{stop.id}.pdf"
          end
          media_paths[stop.id] = paths
        end

        # One PDF file per delivery note; bounded WeasyPrint pool for export latency.
        pdf_by_stop_id = render_delivery_note_pdfs(pending_notes)
        pending_notes.each do |stop|
          rel = media_paths[stop.id][:delivery_note]
          zio.put_next_entry(rel)
          zio.write pdf_by_stop_id.fetch(stop.id)
        end

        zio.put_next_entry('stops.csv')
        zio.write to_csv(excel: true, media_paths: media_paths, track_paths: track_paths)

        zio.put_next_entry('index.html')
        zio.write render_index(media_paths, track_paths)
      end
    end

    private

    def preload_routes
      ActiveRecord::Associations::Preloader.new.preload(@operation, customer: :custom_attributes)
      @operation.operation_routes
                .order(:index, :id)
                .includes_for_export
                .to_a
    end

    def each_stop
      @routes.each do |route|
        route.operation_stops.sort_by { |stop| [stop.index.to_i, stop.id] }.each do |stop|
          yield route, stop
        end
      end
    end

    def render_delivery_note_pdfs(stops)
      return {} if stops.empty?

      size = PDF_POOL_SIZE.clamp(1, stops.size)
      queue = Queue.new
      stops.each_with_index { |stop, index| queue << [index, stop] }
      size.times { queue << nil }

      results = Array.new(stops.size)
      workers = Array.new(size) {
        Thread.new {
          while (job = queue.pop)
            index, stop = job
            ActiveRecord::Base.connection_pool.with_connection do
              results[index] = [stop.id, DeliveryNotePdf.call(operation_stop: stop)]
            end
          end
        }
      }
      workers.each(&:join)
      results.to_h
    end

    def route_board(route)
      @route_boards ||= {}
      @route_boards[route.id] ||= route.board
    end

    def row_for(route, stop, paths, track_file)
      place = stop.list_fields
      dest = stop.destination_snapshot.presence || stop.store_snapshot || {}
      snap = stop.stop_snapshot || {}
      board = @operation_board
      rboard = route_board(route)
      rsnap = route.route_snapshot || {}
      [
        @operation.date,
        @operation.ref,
        @operation.name,
        @operation.status,
        board[:delivered],
        board[:failed],
        board[:exception],
        board[:total],
        board[:delay],
        route.index,
        route.ref,
        route.vehicle_name,
        route.driver_email,
        route.driver_phone,
        rboard[:delivered],
        rboard[:failed],
        rboard[:exception],
        rboard[:total],
        rsnap['distance'],
        rsnap['drive_time'],
        rsnap['duration'],
        stop.index,
        stop.kind,
        stop.status,
        place['ref'],
        place['visit_ref'],
        place['name'],
        place['street'],
        place['postalcode'],
        place['city'],
        place['country'],
        place['phone_number'],
        dest['email'],
        place['detail'],
        place['comment'],
        place['lat'],
        place['lng'],
        stop.planned_arrival_clock,
        stop.planned_departure_clock,
        stop.actual_arrival_clock,
        stop.actual_departure_clock,
        stop.delay_minutes,
        stop.time_windows_label,
        snap['distance'],
        snap['drive_time'],
        snap['wait_time'],
        stop.custom_attributes.is_a?(Hash) ? stop.custom_attributes['_note'] : nil,
        quantities_label(stop),
        Array(paths[:photos]).join(' | '),
        paths[:signature],
        paths[:delivery_note],
        track_file
      ]
    end

    def quantities_label(stop)
      stop.quantity_lines.map { |line|
        actual = stop.actual_quantity(line[:kind], line[:unit_id])
        planned = line[:value]
        value = actual.nil? ? planned : actual
        "#{line[:label]}=#{value}"
      }.join(' | ')
    end

    def pack_stop_media!(zio, route, stop)
      paths = { photos: [], signature: nil, delivery_note: nil }
      stop.photos.each_with_index do |photo, index|
        rel = "media/route_#{route.id}/stop_#{stop.id}/photos/#{safe_filename(photo.filename.to_s, "photo_#{index + 1}.jpg")}"
        zio.put_next_entry(rel)
        zio.write photo.blob.download
        paths[:photos] << rel
      end
      if stop.signature.attached?
        ext = File.extname(stop.signature.filename.to_s).presence || '.png'
        rel = "media/route_#{route.id}/stop_#{stop.id}/signature#{ext}"
        zio.put_next_entry(rel)
        zio.write stop.signature.blob.download
        paths[:signature] = rel
      end
      paths
    end

    def pack_route_track!(zio, route)
      geojson = route_track_geojson(route)
      return if geojson[:features].empty?

      rel = "tracks/route_#{route.id}.geojson"
      zio.put_next_entry(rel)
      zio.write JSON.generate(geojson)
      rel
    end

    def route_track_geojson(route)
      features = []
      Array(route.route_snapshot&.[]('tracks')).each do |track|
        coords = coordinates_for(track)
        next if coords.size < 2

        features << {
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: coords },
          properties: {
            kind: 'planned',
            operation_route_id: route.id,
            vehicle_name: route.vehicle_name,
            color: route.vehicle_color
          }
        }
      end

      positions = route.vehicle_positions.sort_by { |p| p.positioned_at || Time.at(0) }.filter_map { |p|
        next if p.lat.blank? || p.lng.blank?

        [p.lng.to_f, p.lat.to_f]
      }
      if positions.size >= 2
        features << {
          type: 'Feature',
          geometry: { type: 'LineString', coordinates: positions },
          properties: {
            kind: 'positions',
            operation_route_id: route.id,
            vehicle_name: route.vehicle_name
          }
        }
      end

      { type: 'FeatureCollection', features: features }
    end

    def coordinates_for(track)
      track = track.stringify_keys
      return track['coordinates'] if track['coordinates'].present?
      return [] if track['polylines'].blank?

      FastPolylines.decode(track['polylines'], 6).map { |lat, lng| [lng.to_f, lat.to_f] }
    end

    def safe_filename(name, fallback)
      base = File.basename(name.to_s).gsub(/[^\w.\-]+/, '_')
      base.presence || fallback
    end

    def render_index(media_paths, track_paths)
      ApplicationController.render(
        template: 'operations/export/index',
        layout: false,
        assigns: {
          operation: @operation,
          routes: @routes,
          media_paths: media_paths,
          track_paths: track_paths,
          operation_board: @operation_board,
          route_boards: @routes.index_with { |route| route_board(route) }
        }
      )
    end

  end
end
