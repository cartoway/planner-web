# Copyright © Mapotempo, 2013-2016
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
class Zoning < ApplicationRecord
  belongs_to :customer
  has_many :zones, inverse_of: :zoning, dependent: :delete_all, autosave: true, after_add: :touch_zones, after_remove: :touch_zones
  has_and_belongs_to_many :plannings, autosave: true

  default_scope { order(:id) }

  accepts_nested_attributes_for :zones, allow_destroy: true

  nilify_blanks
  auto_strip_attributes :name
  validates :name, presence: true

  before_create :update_outdated, :check_max_zoning
  before_save :update_outdated

  attr_accessor :prefered_unit

  amoeba do
    exclude_association :plannings

    customize(lambda { |_original, copy|
      def copy.update_outdated; end

      copy.zones.each{ |zone|
        zone.zoning = copy
      }
    })
  end

  def self.speed_multiplier_areas(zonings)
    zonings.collect(&:zones).flatten.select{ |z| z.speed_multiplier != 1 }.collect{ |z|
      feat = RGeo::GeoJSON.decode(z.polygon, json_parser: :json)
      coordinates = feat.geometry.coordinates[0] if feat && feat.geometry.geometry_type == RGeo::Feature::Polygon
      coordinates = feat.geometry.coordinates[0][0] if feat && feat.geometry.geometry_type == RGeo::Feature::MultiPolygon
      {
        area: coordinates.collect(&:reverse),
        speed_multiplier_area: z.speed_multiplier
      }
    }
  end

  def duplicate
    copy = self.amoeba_dup
    copy.name += " (#{I18n.l(Time.zone.now, format: :long)})"
    copy
  end

  def apply(visits)
    visits.group_by{ |visit|
      inside(visit.destination)
    }
  end

  # Return the zone with vehicle and max distance from the border
  def inside(destination)
    z = zones.select(&:vehicle_id).collect{ |zone|
      [zone, zone.inside_distance(destination.lat, destination.lng)]
    }.select{ |_zone, d|
      d
    }.max_by{ |_zone, d|
      d
    }
    z[0] if z
  end

  def flag_outdated
    plannings.each{ |planning|
      planning.zoning_outdated = true
    }
  end

  def automatic_clustering(planning, n, out_of_route = true)
    if planning
      routes = out_of_route ? planning.routes : planning.routes.select(&:vehicle_usage_id)
      stops = routes.map(&:stops).flatten.uniq
    end
    positions = (stops || customer.destinations).select(&:position?).map{ |position| [position.lat, position.lng] }.compact.uniq
    vehicles = planning ? planning.vehicle_usage_set.vehicle_usages.select(&:active).map(&:vehicle) : customer.vehicles.to_a
    clusters = Clustering.clustering(positions, n || vehicles.size)
    zones.clear
    Clustering.hulls(clusters).each{ |hull|
      zones.build(polygon: hull, vehicle: vehicles.shift)
    }
  end

  def from_planning(planning)
    zones.clear
    clusters = planning.routes.select(&:vehicle_usage_id).collect{ |route|
      route.stops.select{ |stop| stop.is_a?(StopVisit) }.collect{ |stop|
        if stop.position?
          [stop.lat, stop.lng]
        end
      }.compact.uniq
    }
    routes = planning.routes.select(&:vehicle_usage_id)
    Clustering.hulls(clusters).each{ |hull|
      route = routes.shift
      if hull
        name = route.ref ? I18n.t('zonings.default.from_route') + ' ' + route.ref : nil
        zones.build(polygon: hull, name: name, vehicle: route.vehicle_usage.vehicle)
      end
    }
  end

  def isochrone?(vehicle_usage_set, _from_store = true)
    isowhat?(:isochrone?, vehicle_usage_set)
  end

  def isochrone(size, vehicle_usage = nil, loc = nil, time = nil)
    isowhat(:isochrone?, :isochrone, size, vehicle_usage, loc, time)
  end

  def isochrones(size, vehicle_usage_set, date)
    isowhats(:isochrone?, :isochrone, size, vehicle_usage_set, date)
  end

  def isodistance?(vehicle_usage_set, _from_store = true)
    isowhat?(:isodistance?, vehicle_usage_set)
  end

  def isodistance(size, vehicle_usage = nil, loc = nil, time = nil)
    isowhat(:isodistance?, :isodistance, size, vehicle_usage, loc, time)
  end

  def isodistances(size, vehicle_usage_set, date)
    isowhats(:isodistance?, :isodistance, size, vehicle_usage_set, date)
  end

  private

  def update_outdated
    flag_outdated if @collection_touched
  end

  def check_max_zoning
    !self.customer.too_many_zonings? || raise(Exceptions::OverMaxLimitError.new(I18n.t('activerecord.errors.models.customer.attributes.zonings.over_max_limit')))
  end

  def touch_zones(_zone)
    @collection_touched = true
  end

  def isowhat?(what, vehicle_usage_set, from_store = true)
    vehicle_usage_set.vehicle_usages.where(active: true).with_vehicle.find{ |vehicle_usage|
      router = vehicle_usage.vehicle.default_router
      router.method(what).call && (vehicle_usage.default_store_start.try(&:position?) || !from_store)
    }
  end

  def isowhats(what_qm, what, size, vehicle_usage_set, date = nil)
    zones.clear
    vehicle_usage_set.vehicle_usages.select(&:active).each{ |vehicle_usage|
      # Use Time.zone.parse to preserve time zone from user (instead of to_time)
      isowhat(what_qm, what, size, vehicle_usage, nil, date && vehicle_usage.vehicle.default_router_options['traffic'] ? Time.zone.parse(date.to_s) + vehicle_usage.default_time_window_start : nil)
    }
  end

  def isowhat(what_qm, what, size, vehicle_usage, loc, time)
    return unless vehicle_usage || loc
    router = vehicle_usage ? vehicle_usage.vehicle.default_router : customer.router

    size_to_human = (what == :isochrone) ? ((size / 60).to_s + ' ' + I18n.t('all.unit.minute')) : get_isodistance_name(size / 1000)
    name = I18n.t('zonings.default.from_' + what.to_s) + ' ' + size_to_human

    if !loc
      loc = [vehicle_usage.default_store_start.try(&:lat), vehicle_usage.default_store_start.try(&:lng)]
      name += ' ' + I18n.t('zonings.default.from') + ' ' + vehicle_usage.default_store_start.name if vehicle_usage.try(&:default_store_start)
    end
    name += ' ' + I18n.l(time, format: :short) if time && router.options['traffic']

    if router.method(what_qm).call && loc[0] && loc[1]
      router_options = (vehicle_usage ? vehicle_usage.vehicle.default_router_options : customer.router_options).symbolize_keys
      router_options[:departure] = time
      router_options[:speed_multiplier] = vehicle_usage ? vehicle_usage.vehicle.default_speed_multiplier : customer.speed_multiplier
      geom = router.method('compute_' + what.to_s).call(loc[0], loc[1], size, router_options)
    end
    if geom
      zone = vehicle_usage && zones.to_a.find{ |zone| zone.vehicle_id == vehicle_usage.vehicle.id }
      if zone
        zone.polygon = geom
        zone.name = name
      else
        zones.build(polygon: geom, name: name, vehicle: vehicle_usage.try(&:vehicle))
      end
    end
  end

  def get_isodistance_name(size)
    !@prefered_unit.nil? && @prefered_unit != 'km' ? (size / 1.609344).round(2).to_s + ' miles' : size.to_s + ' ' + ' km'
  end

end
