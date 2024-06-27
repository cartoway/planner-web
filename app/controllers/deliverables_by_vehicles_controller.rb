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

class DeliverablesByVehiclesController < ApplicationController
  include DeliverableByVehiclesHelper

  before_action :authenticate_user!
  before_action :set, only: %i[show]

  def show; end

  private

  def deliverables_by_vehicle_params
    params.require(:vehicle_id)
    params.require(:planning_ids)
    params.permit(:vehicle_id, :planning_ids)
  end

  def set
    p = deliverables_by_vehicle_params

    @customer = current_user.customer
    deliverable_units = @customer.deliverable_units
    @plannings = plannings_by_ids @customer, p[:planning_ids]
    routes = routes_by_vehicle @plannings, p[:vehicle_id]
    @routes_quantities = routes_quantities_by_deliverables routes, deliverable_units
    @routes_total_infos = routes_total_infos(@routes_quantities, routes)
  end
end
