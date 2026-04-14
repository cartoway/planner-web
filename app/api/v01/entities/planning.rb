# Copyright © Mapotempo, 2014-2015
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

# Aggregate each route's primary route_data (sizes, alert flags) for planning API payloads.
class V01::Entities::PlanningRouteDataAlerts
  INTEGER_FIELDS = Route::ROUTE_DATA_METRICS_FIELDS.first(4).freeze
  BOOLEAN_FIELDS = (Route::ROUTE_DATA_METRICS_FIELDS - INTEGER_FIELDS).freeze

  # Returns a string-keyed hash; recomputed at most once per planning instance per serialization pass.
  def self.serialize(planning)
    cache = :@_route_metrics_json
    return planning.instance_variable_get(cache) if planning.instance_variable_defined?(cache)

    rds = planning.routes.map(&:route_data).compact
    out = if rds.empty?
      empty_aggregate_hash
    else
      h = {}
      INTEGER_FIELDS.each { |k| h[k] = rds.sum { |rd| rd.public_send(k).to_i } }
      BOOLEAN_FIELDS.each { |k| h[k] = rds.any? { |rd| rd.public_send(k) } }
      h
    end
    result = out.stringify_keys
    planning.instance_variable_set(cache, result)
    result
  end

  def self.empty_aggregate_hash
    h = {}
    INTEGER_FIELDS.each { |k| h[k] = 0 }
    BOOLEAN_FIELDS.each { |k| h[k] = false }
    h
  end
end

class V01::Entities::Planning < Grape::Entity
  AGGREGATE_BASE = 'Aggregated from each route main route_data'.freeze

  def self.entity_name
    'V01_Planning'
  end

  def self.aggregate_field_doc(attr)
    if V01::Entities::PlanningRouteDataAlerts::INTEGER_FIELDS.include?(attr)
      { type: Integer, desc: "#{AGGREGATE_BASE}: sum of #{attr}." }
    else
      { type: 'Boolean', desc: "#{AGGREGATE_BASE}: true if any route has #{attr}." }
    end
  end

  # Read-only aggregates must not appear in POST/PUT param documentation.
  def self.documentation_for_params
    documentation.except(:id, :route_ids, :outdated, :tag_ids, *Route::ROUTE_DATA_METRICS_FIELDS)
  end

  expose(:id, documentation: { type: Integer })
  expose(:name, documentation: { type: String })
  expose(:ref, documentation: { type: String })
  expose(:date, documentation: { type: Date })
  expose(:begin_date, documentation: { type: Date, desc: 'Begin validity period' })
  expose(:end_date, documentation: { type: Date, desc: 'End validity period' })
  expose(:active, documentation: { type: 'Boolean', default: true })
  expose(:vehicle_usage_set_id, documentation: { type: Integer })
  expose(:zoning_id, documentation: { type: Integer, desc: 'DEPRECATED. Use zoning_ids instead.' }) { |p|
    p.zonings.first.id if p.zonings.size == 1
  }
  expose(:zoning_ids, documentation: { type: Integer, desc: 'If a new zoning is specified before planning save, all visits will be affected to vehicles specified in zones.', is_array: true })
  expose(:zoning_outdated, as: :zoning_out_of_date, documentation: { type: 'Boolean', desc: 'DEPRECATED. Use zoning_outdated instead.' })
  expose(:zoning_outdated, documentation: { type: 'Boolean' })
  expose(:outdated, as: :out_of_date, documentation: { type: 'Boolean', desc: 'DEPRECATED. Use outdated instead.' })
  expose(:outdated, documentation: { type: 'Boolean' })
  expose(:route_ids, documentation: { type: Integer, is_array: true }) { |m| m.routes.collect(&:id) } # Workaround bug with fetch join stops
  expose(:tag_ids, documentation: { type: Integer, desc: 'Restrict visits/destinations in the plan (visits/destinations should have all of these tags to be present in the plan).', is_array: true })
  expose(:tag_operation, documentation: { type: String, values: ['and', 'or'], desc: 'Choose how to use selected tags: and (for visits with all tags, by default) / or (for visits with at least one tag).', default: 'and' }) { |m|
    m.tag_operation.delete_prefix('_')
  }
  expose(:updated_at, documentation: { type: DateTime, desc: 'Last Updated At'})
  Route::ROUTE_DATA_METRICS_FIELDS.each do |attr|
    expose(attr, documentation: V01::Entities::Planning.aggregate_field_doc(attr)) { |p|
      V01::Entities::PlanningRouteDataAlerts.serialize(p)[attr.to_s]
    }
  end
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] && options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == 'polyline'
          :polyline
        elsif options[:geojson] == 'point'
          false
        else
          true
        end)
    end
  }
end
