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

include PlanningIcalendar
include IcalendarUrlHelper

class V01::RoutesGet < Grape::API
  content_type :json, 'application/json'
  content_type :geojson, 'application/vnd.geo+json'
  content_type :xml, 'application/xml'
  content_type :ics, 'text/calendar'
  default_format :json

  helpers do
    def present_routes(routes, params)
      if env['api.format'] == :geojson
        Route.routes_to_geojson(routes, params[:stores] || params[:with_stores], true,
          if params[:with_geojson] == :polyline
            :polyline
          elsif params[:with_geojson] == :point
            false
          else
            true
          end,
          params[:quantities] || params[:with_quantities])
      else
        present routes, with: V01::Entities::Route, geojson: params[:with_geojson]
      end
    end
  end

  resource :routes do
    desc 'Fetch customer\'s routes.',
      nickname: 'getRoutes',
      is_array: true,
      success: V01::Status.success(:code_200, V01::Entities::Route),
      failure: V01::Status.failures(is_array: true)
    params do
      optional :ids, type: Array[String], desc: 'Select returned routes by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
      optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry, when using json output. For geojson output, param can be only set to `point` to return only points, `polyline` to return with encoded linestring.'
      optional :stores, type: Boolean, default: false, desc: 'Include the stores when using geojson output.'
      optional :quantities, type: Boolean, default: false, desc: 'Include the quantities when using geojson output.'
    end
    get do
      routes = if params.key?(:ids)
        current_customer.plannings.flat_map(&:routes).select{ |route|
          params[:ids].any?{ |s| ParseIdsRefs.match(s, route) }
        }
      else
        current_customer.plannings.flat_map{ |p| p.routes.includes_vehicle_usages.load }
      end
      present_routes routes, params
    end
  end

  resource :plannings do
    params do
      requires :planning_id, type: String, desc: SharedParams::ID_DESC
    end
    segment '/:planning_id' do
      resource :routes do
        desc 'Fetch planning\'s routes.',
          nickname: 'getRoutes',
          is_array: true,
          success: V01::Status.success(:code_200, V01::Entities::Route),
          failure: V01::Status.failures(is_array: true)
        params do
          optional :ids, type: Array[String], desc: 'Select returned routes by id separated with comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', coerce_with: CoerceArrayString
          optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry, when using json output. For geojson output, param can be only set to `point` to return only points, `polyline` to return with encoded linestring.'
          optional :stores, type: Boolean, default: false, desc: 'Include the stores when using geojson output.'
          optional :quantities, type: Boolean, default: false, desc: 'Include the quantities when using geojson output.'
        end
        get do
          routes = if params.key?(:ids)
            current_customer.plannings.where(ParseIdsRefs.where_clause([params[:planning_id]])).first!.routes.select{ |route|
              params[:ids].any?{ |s| ParseIdsRefs.match(s, route) }
            }
          else
            current_customer.plannings.where(ParseIdsRefs.where_clause([params[:planning_id]])).first!.routes.includes_vehicle_usages.load
          end
          present_routes routes, params
        end

        desc 'Fetch route.',
          nickname: 'getRoute',
          http_codes: [
            V01::Status.success(:code_200, V01::Entities::Route),
            V01::Status.success(:code_204)
          ].concat(V01::Status.failures)
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry, when using json output. For geojson output, param can be only set to `point` to return only points, `polyline` to return with encoded linestring.'
        end
        get ':id' do
          r = current_customer.plannings.where(ParseIdsRefs.where_clause([params[:planning_id]])).first!.routes.where(ParseIdsRefs.where_clause([params[:id]])).first!
          if params.key?(:email)
            vehicle = r.vehicle_usage_id && r.vehicle_usage.vehicle
            if vehicle
              route_to_send = Hash[
                vehicle.contact_email,
                [
                  vehicle: vehicle,
                  routes: [
                    url: api_route_calendar_path(r, api_key: @current_user.api_key),
                    route: r
                  ]
                ]
              ]
              route_calendar_email route_to_send
            end
            status 204
          elsif env['api.format'] == :geojson
            r.to_geojson(true, true,
              if params[:with_geojson] == :polyline
                :polyline
              elsif params[:with_geojson] == :point
                false
              else
                true
              end)
          elsif env['api.format'] == :ics
            route_calendar(r).to_ical
          else
            present r, with: V01::Entities::Route, geojson: params[:with_geojson]
          end
        end
      end
    end
  end
end
