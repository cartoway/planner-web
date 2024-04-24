# Copyright © Mapotempo, 2018
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
class RoutesByVehiclesController < ApplicationController
  before_action :authenticate_user!
  before_action :manage_routes

  load_and_authorize_resource :vehicle

  def show
    @routes = current_user.customer.plannings.select{ |p|
      !params.key?(:planning_ids) || params[:planning_ids].split(',').include?("#{p.id}")
    }.map{ |p|
      p.routes.find{ |r|
        r.vehicle_usage_id && r.vehicle_usage.vehicle_id == @vehicle.id
      }
    }
    @with_stops = true
    @with_planning = true
    capabilities
  end

  def self.manage
    Hash[[:destination, :store].map{ |v| ["manage_#{v}".to_sym, true] }]
  end

  private

  def manage_routes
    @manage_routes = RoutesByVehiclesController.manage
  end

  def capabilities
    vehicle_usage_sets = @routes.map{ |r| r.planning.vehicle_usage_set }.uniq
    @isochrone = vehicle_usage_sets.map{ |v| [v, Zoning.new.isochrone?(v, false)] }
    @isodistance = vehicle_usage_sets.map{ |v| [v, Zoning.new.isodistance?(v, false)] }
    @isoline_need_time = vehicle_usage_sets.map{ |v|
      [v, v.vehicle_usages.any?{ |vu| vu.vehicle.default_router_options['traffic'] }]
    }
  end
end
