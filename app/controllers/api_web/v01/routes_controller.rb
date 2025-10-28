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
class ApiWeb::V01::RoutesController < ApiWeb::V01::ApiWebController
  skip_before_action :verify_authenticity_token # because rails waits for a form token with POST
  load_and_authorize_resource :planning
  load_and_authorize_resource through: :planning


  def index
    @routes = if params.key?(:ids)
      ids = params[:ids].split(',')
      @planning.routes.includes_destinations_and_stores.where(ParseIdsRefs.where_clause(ids)).includes_vehicle_usages
    else
      @planning.routes.includes_destinations_and_stores.includes_vehicle_usages
    end
    @layer = current_user.customer.profile.layers.find_by(id: params[:layer_id]) if params[:layer_id]
    @disable_clusters = ValueToBoolean.value_to_boolean(params[:disable_clusters], false)
  end

  def print
    @params = params
    @route = @planning.routes.includes_destinations_and_stores.find(params[:id])

    respond_to do |format|
      format.html
    end
  end
end
