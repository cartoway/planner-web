# Copyright © Mapotempo, 2015-2016
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
V01::Stores.class_eval do
  desc 'Fetch customer\'s stores by distance.',
    nickname: 'getStoresByDistance',
    is_array: true,
    entity: V01::Entities::Store
  params do
    requires :lat, type: Float, desc: 'Point latitude.'
    requires :lng, type: Float, desc: 'Point longitude.'
    requires :n, type: Integer, desc: 'Number of results.'
    optional :vehicle_usage_id, type: Integer, desc: 'Vehicle Usage uses in place of default router and speed multiplicator.'
  end
  get :stores_by_distance do
    position = OpenStruct.new(lat: Float(params[:lat]), lng: Float(params[:lng]))
    vehicle_usage = VehicleUsage.joins(:vehicle_usage_set).where(vehicle_usage_sets: {customer_id: current_customer.id}, id: params[:vehicle_usage_id]).first
    if params.key?(:vehicle_usage_id) && vehicle_usage.nil?
      error! 'VehicleUsage not found', 404
    else
      stores = current_customer.stores_by_distance(position, Integer(params[:n]), vehicle_usage)
      present stores, with: V01::Entities::Store
    end
  end
end
