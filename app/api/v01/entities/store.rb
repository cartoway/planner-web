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
class V01::Entities::Store < Grape::Entity
  def self.entity_name
    'V01_Store'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 1 })
  expose(:ref, documentation: { type: String, desc: 'External unique reference. Upsert key on import.', example: 'DEPOT-NORD' })
  expose(:name, documentation: { type: String, desc: 'Display name.', example: 'North depot' })
  expose(:street, documentation: { type: String, desc: 'Street and house number. Geocoded when lat/lng are omitted.', example: '1 rue du Depot' })
  expose(:postalcode, documentation: { type: String, desc: 'Postal / ZIP code.', example: '33000' })
  expose(:city, documentation: { type: String, desc: 'City.', example: 'Bordeaux' })
  expose(:state, documentation: { type: String, desc: 'State / region.' })
  expose(:country, documentation: { type: String, desc: 'Country. Falls back to customer default_country when omitted.', example: 'France' })
  expose(:lat, documentation: { type: Float, desc: 'Latitude. Omitted or empty with an address triggers geocoding.', example: 44.84 })
  expose(:lng, documentation: { type: Float, desc: 'Longitude. Omitted or empty with an address triggers geocoding.', example: -0.58 })
  expose(:color, documentation: { type: String, desc: "Color code with #. Default: #{Planner::Application.config.store_color_default}.", example: '#0000FF' })
  expose(:icon, documentation: { type: String, desc: "Icon name from font-awesome. Default: #{Planner::Application.config.store_icon_default}." })
  expose(:icon_size, documentation: { type: String, values: MapIconSize::SIZES, desc: "Icon size. Default: customer store_icon_size or #{Planner::Application.config.store_icon_size_default}." })
  expose(:geocoding_accuracy, documentation: { type: Float, desc: 'Geocoding confidence in 0..1.', example: 0.9 })
  expose(:geocoding_level, documentation: { type: String, values: ['point', 'house', 'street', 'intersection', 'city'], desc: 'Precision of the geocoded position.', example: 'house' })
  expose(:geocoding_result, documentation: { type: JSON, desc: 'Raw geocoder payload (provider-specific).' })
  expose(:geocoded_at, documentation: { type: DateTime, desc: 'When the current coordinates were geocoded.' })
  expose(:geocoder_version, documentation: { type: String, desc: 'Geocoder version that produced the current coordinates.' })
  expose(:store_reloads, using: V01::Entities::StoreReload, documentation: { type: V01::Entities::StoreReload, is_array: true, desc: 'Reload stops defined on this store (only if customer enable_store_stops is on).' }, if: ->(store, _options) { store.customer.enable_store_stops })
end
