# frozen_string_literal: true

require 'zip'
require 'json'

module Operations
  # Spreadsheet + ZIP archive (HTML report, XLSX, proofs, delivery notes, tracks) for one operation.
  class Export
    CSV_HEADERS = %w[
      operation_date operation_ref operation_name operation_status
      route_index route_ref vehicle_name driver_email driver_phone
      route_distance_m route_drive_time_s route_duration_s
      stop_index stop_kind stop_status destination_ref visit_ref name street postalcode city country phone email detail comment
      lat lng
      planned_arrival planned_departure actual_arrival actual_departure delay_minutes time_windows
      stop_distance_m stop_drive_time_s stop_wait_time_s
      quantities photos signature delivery_note
    ].freeze
    # ponytail: bounded WeasyPrint pool; raise EXPORT_PDF_POOL_SIZE if export hosts have spare CPU.
    PDF_POOL_SIZE = (ENV['EXPORT_PDF_POOL_SIZE'].presence || 3).to_i

    def initialize(operation)
      @operation = operation
      @routes = preload_routes
      @operation_board = @operation.board(routes: @routes)
      @stop_custom_attributes = stop_custom_attribute_definitions
    end

    def basename
      parts = [
        'operation',
        sanitize_basename(@operation.name),
        sanitize_basename(@operation.ref),
        @operation.date
      ]
      parts.compact.join('_')
    end

    def to_xlsx
      rows = [header_labels]
      each_stop do |route, stop|
        rows << row_for(route, stop)
      end
      build_xlsx(rows)
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

        zio.put_next_entry('stops.xlsx')
        zio.write to_xlsx

        zio.put_next_entry('index.html')
        zio.write render_index(media_paths, track_paths)
      end
    end

    private

    def header_labels
      CSV_HEADERS.map { |key| I18n.t("operations.export.columns.#{key}") } +
        @stop_custom_attributes.map(&:name)
    end

    def stop_custom_attribute_definitions
      attrs = @operation.customer.custom_attributes
      list = if attrs.loaded?
               attrs.select { |attribute| attribute.stop_visit? || attribute.stop_store? }
             else
               attrs.where(object_class: %i[stop_visit stop_store]).to_a
             end
      list.sort_by(&:name).uniq(&:name)
    end

    # Minimal OOXML workbook (no extra gem): one sheet, inline strings + numbers.
    def build_xlsx(rows)
      Zip::OutputStream.write_buffer do |zio|
        zio.put_next_entry('[Content_Types].xml')
        zio.write <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
            <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
            <Default Extension="xml" ContentType="application/xml"/>
            <Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
            <Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
          </Types>
        XML

        zio.put_next_entry('_rels/.rels')
        zio.write <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
          </Relationships>
        XML

        zio.put_next_entry('xl/workbook.xml')
        zio.write <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
            <sheets>
              <sheet name="Stops" sheetId="1" r:id="rId1"/>
            </sheets>
          </workbook>
        XML

        zio.put_next_entry('xl/_rels/workbook.xml.rels')
        zio.write <<~XML
          <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
          <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
            <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
          </Relationships>
        XML

        zio.put_next_entry('xl/worksheets/sheet1.xml')
        zio.write xlsx_sheet_xml(rows)
      end.string
    end

    def xlsx_sheet_xml(rows)
      xml = +%Q(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n)
      xml << %Q(<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>)
      rows.each_with_index do |row, row_index|
        r = row_index + 1
        xml << %Q(<row r="#{r}">)
        row.each_with_index do |value, col_index|
          ref = "#{xlsx_col_name(col_index)}#{r}"
          if value.nil?
            next
          elsif value.is_a?(Numeric)
            xml << %Q(<c r="#{ref}"><v>#{value}</v></c>)
          else
            xml << %Q(<c r="#{ref}" t="inlineStr"><is><t>#{xlsx_escape(value)}</t></is></c>)
          end
        end
        xml << '</row>'
      end
      xml << '</sheetData></worksheet>'
    end

    def xlsx_col_name(index)
      name = +''
      n = index + 1
      while n.positive?
        n, rem = (n - 1).divmod(26)
        name.prepend(('A'.ord + rem).chr)
      end
      name
    end

    def xlsx_escape(value)
      value.to_s
           .gsub(/[\x00-\x08\x0B\x0C\x0E-\x1F]/, '')
           .gsub('&', '&amp;')
           .gsub('<', '&lt;')
           .gsub('>', '&gt;')
    end

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

    def row_for(route, stop)
      place = stop.list_fields
      dest = stop.destination_snapshot.presence || stop.store_snapshot || {}
      snap = stop.stop_snapshot || {}
      rsnap = route.route_snapshot || {}
      [
        @operation.date,
        @operation.ref,
        @operation.name,
        @operation.status,
        route.index,
        route.ref,
        route.vehicle_name,
        route.driver_email,
        route.driver_phone,
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
        quantities_label(stop),
        stop.photos.size,
        export_yes_no(stop.signature.attached?),
        export_yes_no(stop.delivery_note_exportable?),
        *@stop_custom_attributes.map { |attribute| stop_custom_attribute_value(stop, attribute) }
      ]
    end

    def export_yes_no(present)
      present ? I18n.t('all.value._yes') : I18n.t('all.value._no')
    end

    def stop_custom_attribute_value(stop, definition)
      return unless stop_custom_attribute_applies?(stop, definition)

      bag = (stop.stop_snapshot&.[]('custom_attributes') || {}).merge(stop.custom_attributes || {})
      key = CustomAttribute.storage_key_for(definition.name)
      return unless bag.key?(key)

      format_stop_custom_attribute(definition, bag[key])
    end

    def stop_custom_attribute_applies?(stop, definition)
      (definition.stop_visit? && stop.kind == 'visit') || (definition.stop_store? && stop.kind == 'store')
    end

    def format_stop_custom_attribute(definition, value)
      case definition.object_type
      when 'boolean'
        ActiveRecord::Type::Boolean.new.cast(value) ? I18n.t('all.value._yes') : I18n.t('all.value._no')
      when 'integer'
        value.nil? ? nil : value.to_i
      when 'float'
        value.nil? ? nil : value.to_f
      when 'array'
        Array(value).reject(&:blank?).join(' / ').presence
      else
        value
      end
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

    def sanitize_basename(value)
      value.to_s.tr('/', '-').gsub(/[^\p{L}\p{N}.\-]+/u, '_').gsub(/_+\z/, '').presence
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
