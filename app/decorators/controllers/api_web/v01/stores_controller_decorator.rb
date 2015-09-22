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
require 'ostruct'

ApiWeb::V01::StoresController.class_eval do
  swagger_api :by_distance do
    summary 'Display the N closest stores of a point.'
    param :query, :lat, :float, :required, 'Point latitude.'
    param :query, :lng, :float, :required, 'Point longitude.'
    param :query, :n, :integer, :required, 'Number of results.'
  end

  def by_distance
    @customer = current_user.customer
    @position = OpenStruct.new(lat: Float(params[:lat]), lng: Float(params[:lng]))
    stores = @customer.stores_by_distance(@position)
    @stores = stores.sort_by{ |store, distance| distance }
    @stores = @stores[0..[Float(params[:n]), @stores.size].min - 1].collect{ |store, distance| store }
  end
end
