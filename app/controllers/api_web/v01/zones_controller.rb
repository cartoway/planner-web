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
require 'value_to_boolean'

class ApiWeb::V01::ZonesController < ApiWeb::V01::ApiWebController
  skip_before_action :verify_authenticity_token # because rails waits for a form token with POST
  load_and_authorize_resource :zoning
  load_and_authorize_resource :zone, through: :zoning

  def index
    @customer = current_user.customer
    @zones =
      if params.key?(:ids)
        ids = params[:ids].split(',')
        @zoning.zones.select{ |zone| ids.include?(zone.id.to_s) }
      else
        @zoning.zones
      end
    if params.key?(:destination_ids)
      destination_ids = params[:destination_ids].split(',')
      @destinations = current_user.customer.destinations.where(ParseIdsRefs.where(Destination, destination_ids))
    elsif params[:destinations] && ValueToBoolean.value_to_boolean(params[:destinations], true)
      @destinations = current_user.customer.destinations
      @destinations_all = true
    end
    if params.key?(:store_ids)
      @stores = current_user.customer.stores.where(ParseIdsRefs.where(Store, params[:store_ids].split(',')))
    end
    @vehicle_usage_set =
      if params[:vehicle_usage_set_id]
        current_user.customer.vehicle_usage_sets.find(params[:vehicle_usage_set_id])
      elsif params[:planning_id]
        current_user.customer.plannings.find(params[:planning_id]).vehicle_usage_set
      elsif current_user.customer.vehicle_usage_sets.size == 1
        current_user.customer.vehicle_usage_sets.first
      end
    @method = request.method_symbol
  end
end
