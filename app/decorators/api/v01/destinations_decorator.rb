# Copyright © Mapotempo, 2015
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
V01::Destinations.class_eval do
  desc 'Fetch customer\'s destinations inside time/distance.',
    nickname: 'getDestinationsInsideTimeAndDistance',
    is_array: true,
    entity: V01::Entities::Destination
  params do
    requires :lat, type: Float, desc: 'Point latitude.'
    requires :lng, type: Float, desc: 'Point longitude.'
    optional :distance, type: Integer, desc: 'Maximum distance in km.'
    optional :time, type: Integer, desc: 'Maximum time in seconds.'
    at_least_one_of :time, :distance
  end
  get :destinations_by_time_and_distance do
    position = OpenStruct.new(lat: Float(params[:lat]), lng: Float(params[:lng]))
    destinations = current_customer.destinations_inside_time_distance(position, params[:distance], params[:time]) || []
    present destinations, with: V01::Entities::Destination
  end
end
