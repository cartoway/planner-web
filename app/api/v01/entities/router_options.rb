# Copyright © Mapotempo, 2017
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
class V01::Entities::RouterOptions < Grape::Entity
  def self.entity_name
    'V01_RouterOptions'
  end

  # expose(:traffic, documentation: { type: 'Boolean' }) { |m| m['traffic'] }
  expose(:track, documentation: { type: 'Boolean' }) { |m| m['track'] }
  expose(:low_emission_zone, documentation: { type: 'Boolean' }) { |m| m['low_emission_zone'] }
  expose(:motorway, documentation: { type: 'Boolean' }) { |m| m['motorway'] }
  expose(:toll, documentation: { type: 'Boolean' }) { |m| m['toll'] }
  expose(:trailers, documentation: { type: Integer }) { |m| m['trailers'] }
  expose(:weight, documentation: { type: Float, desc: 'Total weight with trailers and shipping goods, in tons' }) { |m| m['weight'] }
  expose(:weight_per_axle, documentation: { type: Float }) { |m| m['weight_per_axle'] }
  expose(:height, documentation: { type: Float }) { |m| m['height'] }
  expose(:width, documentation: { type: Float }) { |m| m['width'] }
  expose(:length, documentation: { type: Float }) { |m| m['length'] }
  expose(:hazardous_goods, documentation: { type: String, values: %w(explosive gas flammable combustible organic poison radio_active corrosive poisonous_inhalation harmful_to_water other)}) { |m| m['hazardous_goods'] }
  expose(:max_walk_distance, documentation: { type: Float }) { |m| m['max_walk_distance'] }
  expose(:approach, documentation: { type: String, values: ['unrestricted', 'curb'] })
  expose(:snap, documentation: { type: Float }) { |m| m['snap'] }
  expose(:strict_restriction, documentation: { type: 'Boolean' }) { |m| m['strict_restriction'] }
end
