# Copyright © Cartoway, 2025
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class V01::RouteData < Grape::API
  helpers do
    def route_data_params
      declared(params, include_missing: false).slice(:hidden, :color).tap do |p|
        p[:color] = p[:color].presence if p.key?(:color)
      end
    end
  end

  resource :route_data do
    desc 'Update route data attributes.',
      nickname: 'updateRouteData',
      success: V01::Status.success(:code_200, V01::Entities::RouteDataProperties),
      failure: V01::Status.failures
    params do
      requires :id, type: Integer, desc: 'RouteData identifier'
      optional :hidden, type: Boolean, desc: 'Hide or show the sub-tour'
      optional :color, type: String, desc: 'Custom color for the sub-tour'
      at_least_one_of :hidden, :color
    end
    patch ':id' do
      route_data = ::RouteData.find(params[:id])
      route_data.update!(route_data_params)

      # Propagate sub-tour color change to related routes' geojson without full recompute
      route = ::Route.where(start_route_data_id: route_data.id).first
      route ||= ::Route.where(stop_route_data_id: route_data.id).first
      route ||= ::Stop.where(route_data_id: route_data.id).includes(:route).first!.route
      route.refresh_geojson_colors_for_route_data(route_data)

      present route_data, with: V01::Entities::RouteDataProperties
    end
  end
end
