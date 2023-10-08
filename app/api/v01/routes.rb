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
require 'coerce'
require 'exceptions'

include PlanningsHelperApi

class V01::Routes < Grape::API
  helpers SharedParams
  helpers do
    # Never trust parameters from the scary internet, only allow the white list through.
    def route_params
      p = ActionController::Parameters.new(params)
      p = p[:route] if p.key?(:route)
      p.permit(:force_start, :start, :hidden, :locked, :ref, :color)
    end

    def get_route
      unless @route
        planning = current_customer.plannings.where(ParseIdsRefs.read(params[:planning_id])).first!
        @route ||= planning.routes.find{ |route| ParseIdsRefs.match(params[:id], route) }
      end
      @route || raise(ActiveRecord::RecordNotFound.new)
    end
  end

  resource :plannings do
    params do
      requires :planning_id, type: String, desc: SharedParams::ID_DESC
    end
    segment '/:planning_id' do
      resource :routes do
        desc 'Update route attributes.',
          nickname: 'updateRoute',
          success: V01::Status.success(:code_200, V01::Entities::RouteProperties),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          use :params_from_entity, entity: V01::Entities::Route.documentation.slice(:force_start, :start, :hidden, :locked, :color)
          optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry: `point` to return only points, `polyline` to return with encoded linestring.'
        end
        put ':id' do
          params[:geojson] = params[:with_geojson]
          params.delete(:with_geojson)

          get_route.update! route_params
          get_route.compute && get_route.save!
          present get_route, with: V01::Entities::RouteProperties
        end

        desc 'Change stops activation.',
          detail: 'Allow to activate/deactivate all stops in a planning\'s route.',
          nickname: 'activationStops',
          success: V01::Status.success(:code_200, V01::Entities::Route),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          requires :active, type: String, values: ['all', 'reverse', 'none']
          optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry: `point` to return only points, `polyline` to return with encoded linestring.'
        end
        patch ':id/active/:active' do
          params[:geojson] = params[:with_geojson]
          params.delete(:with_geojson)

          raise Exceptions::JobInProgressError if Job.on_planning(current_customer.job_optimizer, get_route.planning.id)

          Stop.includes_destinations.scoping do
            get_route.active(params[:active].to_s.to_sym) && get_route.compute
            get_route.save!
            present get_route, with: V01::Entities::Route, geojson: params[:geojson] || params[:with_geojson]
          end
        end

        desc 'Move visit(s) to route. Append in order at end if automatic_insert is false.',
          detail: 'Set a new A route (or vehicle) for a visit which was in a previous B route in the same planning. Automatic_insert parameter allows to compute index of the stops created for visits.',
          nickname: 'moveVisits',
          success: V01::Status.success(:code_204),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          requires :visit_ids, type: Array[String], desc: 'Ids separated by comma. You can specify ref (not containing comma) instead of id, in this case you have to add "ref:" before each ref, e.g. ref:ref1,ref:ref2,ref:ref3.', documentation: {param_type: 'form'}, coerce_with: CoerceArrayString
          optional :automatic_insert, type: Boolean, desc: 'If true, the best index in the route is automatically computed to have minimum impact on total route distance (without taking into account constraints like open/close, you have to start a new optimization if needed).'
        end
        patch ':id/visits/moves' do
          raise Exceptions::JobInProgressError if Job.on_planning(current_customer.job_optimizer, get_route.planning.id)

          Route.includes_destinations.scoping do
            visits = get_route.planning.routes.flat_map{ |r| r.stops.select{ |s| s.is_a?(StopVisit) }.map(&:visit) }
            visits_ordered = []
            params[:visit_ids].each{ |s| visits_ordered << visits.find{ |visit| ParseIdsRefs.match(s, visit) } }
            unless visits_ordered.empty?
              Planning.transaction do
                visits_ordered.each{ |visit| get_route.planning.move_visit(get_route, visit, params[:automatic_insert] ? nil : -1) }
                get_route.planning.compute
                get_route.planning.save!
                status 204
              end
            end
          end
        end

        desc 'Optimize a single route.',
          detail: 'Get the shortest route in time or distance.',
          nickname: 'optimizeRoute',
          http_codes: [
            V01::Status.success(:code_204),
            V01::Status.success(:code_200, V01::Entities::Route)
          ].concat(V01::Status.failures(add: [:code_304]))
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          optional :details, type: Boolean, desc: 'Output Route Details', default: false
          optional :synchronous, type: Boolean, desc: 'Synchronous', default: true
          optional :all_stops, type: Boolean, desc: 'Deprecated (Use active_only instead)'
          optional :active_only, type: Boolean, desc: 'If true only active stops are taken into account by optimization, else inactive stops are also taken into account but are not activated in result route.', default: true
          optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry: `point` to return only points, `polyline` to return with encoded linestring.'
          optional :ignore_overload_multipliers, type: String, desc: "Deliverable Unit id and whether or not it should be ignored : {'0'=>{'unit_id'=>'7', 'ignore'=>'true'}}"
        end
        patch ':id/optimize' do
          params[:geojson] = params[:with_geojson]
          params.delete(:with_geojson)

          begin
            raise Exceptions::JobInProgressError if current_customer.job_optimizer

            Stop.includes_destinations.scoping do
              if !Optimizer.optimize(get_route.planning, get_route, { global: false, synchronous: params[:synchronous], active_only: params[:all_stops].nil? ? params[:active_only] : !params[:all_stops], ignore_overload_multipliers: params[:ignore_overload_multipliers] })
                status 304
              else
                get_route.planning.customer.save!
                if params[:details]
                  present get_route, with: V01::Entities::Route, geojson: params[:geojson] || params[:with_geojson]
                else
                  status 204
                end
              end
            end
          rescue VRPNoSolutionError => e
            error! V01::Status.code_response(:code_304), 304
          end
        end

        desc 'Reverse stops order.',
          detail: 'Reverse all the stops in a route.',
          nickname: 'reverseStopsOrder',
          success: V01::Status.success(:code_200, V01::Entities::Route),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
        end
        patch ':id/reverse_order' do
          Stop.includes_destinations.scoping do
            raise Exceptions::JobInProgressError if Job.on_planning(current_customer.job_optimizer, get_route.planning.id)

            get_route && get_route.reverse_order && get_route.compute!
            get_route.save!
            present get_route, with: V01::Entities::Route
          end
        end

        desc 'Send SMS for each stop visit.',
          detail: 'Send SMS for each stop visit of the specified route.',
          nickname: 'sendSMS',
          success: V01::Status.success(:code_200),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
        end
        get ':id/send_sms' do
          if current_customer.enable_sms && current_customer.reseller.sms_api_key
            Stop.includes_destinations.scoping do
              send_sms_route get_route
            end
          else
            error! V01::Status.code_response(:code_403), 403
          end
        end
      end

      resource :routes_by_vehicle do
        desc 'Fetch route from vehicle.',
          nickname: 'getRouteByVehicle',
          success: V01::Status.success(:code_200, V01::Entities::Route),
          failure: V01::Status.failures
        params do
          requires :id, type: String, desc: SharedParams::ID_DESC
          optional :with_geojson, type: Symbol, values: [:true, :false, :point, :polyline], default: :false, desc: 'Fill the geojson field with route geometry: `point` to return only points, `polyline` to return with encoded linestring.'
        end
        get ':id' do
          params[:geojson] = params[:with_geojson]
          params.delete(:with_geojson)

          planning = current_customer.plannings.find_by! ParseIdsRefs.read(params[:planning_id])
          vehicle = current_customer.vehicles.find_by! ParseIdsRefs.read(params[:id])
          route = planning.routes.find{ |route| route.vehicle_usage_id && route.vehicle_usage.vehicle == vehicle }
          present route, with: V01::Entities::Route, geojson: params[:geojson] || params[:with_geojson]
        end
      end
    end
  end
end
