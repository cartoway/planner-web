# frozen_string_literal: true

# Copyright © Cartoway
#
# Builds a GeoJSON FeatureCollection for the v2 destinations map (MapLibre clustering).
# Supports optional bbox filtering, list-page metadata, and bounds-only responses.
class DestinationsMapGeojson
  EMPTY_FC = { type: 'FeatureCollection', features: [] }.freeze

  def self.build(scope:, per_page:, bbox: nil, highlight_id: nil, bounds_only: false)
    new(scope, per_page, bbox, highlight_id, bounds_only).build
  end

  def initialize(scope, per_page, bbox, highlight_id, bounds_only)
    @scope = scope
    @per_page = per_page.to_i.clamp(1, 100)
    @bbox = bbox
    @highlight_id = highlight_id.presence&.to_i
    @bounds_only = bounds_only
  end

  def build
    return bounds_payload if @bounds_only

    id_to_page = page_by_destination_id
    rows = positioned_rows_in_bbox
    rows = ensure_highlight_row(rows)

    {
      type: 'FeatureCollection',
      features: rows.map { |id, lat, lng, name| feature(id, lat, lng, name, id_to_page[id]) }
    }
  end

  private

  def bounds_payload
    min_lat, max_lat, min_lng, max_lng = bounds_relation.pluck(
      Arel.sql('MIN(destinations.lat)'),
      Arel.sql('MAX(destinations.lat)'),
      Arel.sql('MIN(destinations.lng)'),
      Arel.sql('MAX(destinations.lng)')
    ).first
    return EMPTY_FC.merge(bounds: nil) if min_lat.nil? || min_lng.nil?

    EMPTY_FC.merge(
      bounds: [
        [min_lng.to_f, min_lat.to_f],
        [max_lng.to_f, max_lat.to_f]
      ]
    )
  end

  # ORDER BY on the incoming scope breaks PG MIN/MAX (GroupingError); strip it entirely.
  def bounds_relation
    @scope.positioned.except(:order)
  end

  def page_by_destination_id
    @scope.pluck(:id).each_with_index.to_h { |id, idx| [id, (idx / @per_page) + 1] }
  end

  def positioned_rows_in_bbox
    scope = @scope.positioned
    scope = apply_bbox(scope) if @bbox
    scope.pluck(:id, :lat, :lng, :name)
  end

  def apply_bbox(scope)
    west, south, east, north = @bbox
    scope.where(
      'destinations.lat >= ? AND destinations.lat <= ? AND destinations.lng >= ? AND destinations.lng <= ?',
      south, north, west, east
    )
  end

  def ensure_highlight_row(rows)
    return rows unless @highlight_id
    return rows if rows.any? { |row| row[0] == @highlight_id }

    extra = @scope.where(id: @highlight_id).pick(:id, :lat, :lng, :name)
    return rows unless extra
    return rows if extra[1].nil? || extra[2].nil?

    rows + [extra]
  end

  def feature(id, lat, lng, name, page)
    {
      type: 'Feature',
      id: id,
      geometry: { type: 'Point', coordinates: [lng.to_f, lat.to_f] },
      properties: {
        id: id,
        name: name.to_s,
        page: page || 1
      }
    }
  end
end
