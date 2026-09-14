# Copyright © Mapotempo, 2014-2016
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
class V01::Entities::Destination < Grape::Entity
  def self.entity_name
    'V01_Destination'
  end

  expose(:id, documentation: { type: Integer, desc: 'Internal identifier.', example: 42 })
  expose(:ref, documentation: { type: String, desc: 'External unique reference. Used as upsert key on import. Use ref:VALUE in path/ids filters.', example: 'CLIENT-12' })
  expose(:name, documentation: { type: String, desc: 'Display name.', example: 'Acme' })
  expose(:street, documentation: { type: String, desc: 'Street and house number. Geocoded when lat/lng are omitted.', example: '12 avenue Thiers' })
  expose(:postalcode, documentation: { type: String, desc: 'Postal / ZIP code.', example: '33100' })
  expose(:city, documentation: { type: String, desc: 'City.', example: 'Bordeaux' })
  expose(:state, documentation: { type: String, desc: 'State / region.', example: 'Nouvelle-Aquitaine' })
  expose(:country, documentation: { type: String, desc: 'Country. Falls back to customer default_country when omitted.', example: 'France' })
  expose(:lat, documentation: { type: Float, desc: 'Latitude. Omitted or empty with an address triggers geocoding.', example: 44.8378 })
  expose(:lng, documentation: { type: Float, desc: 'Longitude. Omitted or empty with an address triggers geocoding.', example: -0.5792 })
  expose(:detail, documentation: { type: String, desc: 'Address complement (floor, intercom).', example: '2nd floor' })
  expose(:comment, documentation: { type: String, desc: 'Free comment shown to the driver.', example: 'Call on arrival' })
  expose(:phone_number, documentation: { type: String, desc: 'Contact phone.', example: '+33601020304' })
  expose(:geocoding_accuracy, documentation: { type: Float, desc: 'Geocoding confidence in 0..1. Higher is better.', example: 0.92 })
  expose(:geocoding_level, documentation: { type: String, values: ['point', 'house', 'street', 'intersection', 'city'], desc: 'Precision of the geocoded position.', example: 'house' })
  expose(:geocoding_result, documentation: { type: JSON, desc: 'Raw geocoder payload (provider-specific).' })
  expose(:tag_ids, documentation: { type: Integer, is_array: true, desc: 'Tag ids attached to the destination (skills / filters).', example: [1, 2] })
  expose(:visits, using: V01::Entities::Visit, documentation: { type: V01::Entities::Visit, is_array: true, param_type: 'form', desc: 'Visits (actions) at this destination. Nested on create/update/import.' })
  expose(:geocoded_at, documentation: { type: DateTime, desc: 'When the current coordinates were geocoded.' })
  expose(:geocoder_version, documentation: { type: String, desc: 'Geocoder version that produced the current coordinates.' })
  expose(:duration, documentation: { type: DateTime, desc: 'Extra service duration at the destination, on top of visit duration (HH:MM:SS).' })
end
