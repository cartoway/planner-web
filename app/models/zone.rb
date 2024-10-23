# Copyright © Mapotempo, 2013-2014
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
class Zone < ApplicationRecord
  default_scope { order(:id) }

  belongs_to :zoning, inverse_of: :zones
  belongs_to :vehicle, inverse_of: :zones, optional: true

  nilify_blanks

  validates :polygon, presence: true
  validate :polygon_json_format_validation
  validate :vehicle_from_customer_validation

  after_validation :make_polygon_valid

  before_save :update_outdated

  amoeba do
    enable

    customize(lambda { |_original, copy|
      def copy.polygon_json_format_validation; end

      def copy.vehicle_from_customer_validation; end

      def copy.update_outdated; end
    })
  end

  def inside_distance(lat, lng)
    if !lat.nil? && !lng.nil?
      if (@geom || decode_geom).class == RGeo::GeoJSON::Feature
        inside_feature_distance(@geom.geometry, RGeo::Cartesian.factory.point(lng, lat))
      elsif @geom.class == RGeo::GeoJSON::FeatureCollection
        @geom.collect { |feat|
          inside_feature_distance(feat.geometry, RGeo::Cartesian.factory.point(lng, lat))
        }.min
      end
    end
  end

  def avoid_zone
    speed_multiplier == 0
  end

  def avoid_zone=(bool)
    speed_multiplier = bool ? 0 : 1
  end

  private

  def inside_feature_distance(geom, point)
    inside = geom.contains?(point)
    if inside
      if geom.respond_to?(:exterior_ring)
        geom.exterior_ring.distance(point)
      else
        geom.collect { |geo| geo.exterior_ring.distance(point) }.min
      end
    end
  end

  def decode_geom
    @geom = RGeo::GeoJSON.decode(polygon, json_parser: :json)
  end

  def polygon_json_format_validation
    if polygon
      begin
        !!JSON.parse(polygon)
      rescue
        errors.add(:polygon, :invalid_json)
        false
      end
    end
  end

  def make_polygon_valid
    return unless polygon

    if (@geom || decode_geom).class == RGeo::GeoJSON::Feature
      geometry = edit_invalid_feature(@geom)
      self.polygon = feature_as_geojson(geometry).to_json
    elsif @geom.class == RGeo::GeoJSON::FeatureCollection
      geometries = @geom.map { |feature|
        edit_invalid_feature(feature)
      }
      self.polygon = feature_collection_as_geojson(geometries).to_json
    end
  end

  def edit_invalid_feature(feature)
    invalidity = feature.geometry.invalid_reason

    if invalidity.nil?
      feature.geometry
    else
      begin
        feature.geometry.make_valid
      rescue RGeo::Error
        raise PolygonValidityError.new("Failed to make valid a zone with: #{invalidity.class}")
      end
    end
  end

  def feature_collection_as_geojson(features)
    features.map!{ |feature|
      SimplifyGeometry.polygones_to_coordinates(
        RGeo::GeoJSON.encode(feature),
        **{ precision: 1e-5 }
      )
    }
    {
      type: 'FeatureCollection',
      features: features
    }
  end

  def feature_as_geojson(feature)
    feature =
      SimplifyGeometry.polygones_to_coordinates(
        RGeo::GeoJSON.encode(feature),
        **{ precision: 1e-5 }
      )
    {
      type: 'Feature',
      geometry: feature
    }
  end

  def vehicle_from_customer_validation
    if vehicle && vehicle.customer != zoning.customer
      errors.add(:vehicle, :bad_customer)
      false
    else
      true
    end
  end

  def update_outdated
    zoning.flag_outdated if self.changed? && (polygon_changed? || vehicle_id_changed? || speed_multiplier_changed?)
  end
end
