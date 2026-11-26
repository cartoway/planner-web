# Copyright © Mapotempo, 2016
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
class ApiWeb::V01::PlanningsController < ApiWeb::V01::ApiWebController
  include PlanningToolbarPermissions
  include PlanningOperationHelper

  skip_before_action :verify_authenticity_token # because rails waits for a form token with POST
  before_action :manage_planning

  def edit
    @planning = current_user.customer.plannings.where(ParseIdsRefs.read(params[:id])).first!
    authorize! :edit, @planning
    apply_planning_toolbar_operation_flags!
    @spreadsheet_columns = []
    @with_devices = true
    capabilities
    center = planning_map_center(@planning)
    @map_lat = center[:lat]
    @map_lng = center[:lng]
  end

  def print
    # Explicit preload: Route.includes(...).scoping does not apply to @planning.routes
    # (only Route.default_scope route_data includes fire — classic N+1 on stops/visits/tags).
    @planning = current_user.customer.plannings.where(ParseIdsRefs.read(params[:id])).preload_route_details.first!
    authorize! :print, @planning
    @params = params
    respond_to(&:html)
  end

  def self.manage
    Hash[[:organize, :print].map{ |v| ["manage_#{v}".to_sym, true] }]
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  # permissions should be checked before thanks to CanCan::Ability
  def manage_planning
    @manage_planning = ApiWeb::V01::PlanningsController.manage
  end

  def capabilities
    @isochrone = []
    @isodistance = []
    @isoline_need_time = []
  end
end
