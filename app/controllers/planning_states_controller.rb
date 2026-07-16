# frozen_string_literal: true

# Copyright © Cartoway, 2026
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

require 'value_to_boolean'

class PlanningStatesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_planning
  before_action :set_planning_state, only: [:reapply, :pin]

  include PlanningsHelper
  include ApplicationHelper
  include PlanningStatesHelper
  include PlanningToolbarPermissions
  include PreferencesAuthorization

  before_action :enforce_planning_states_operation!

  def index
    authorize! :read, @planning
    @planning_states = @planning.planning_states.reorder(captured_at: :asc).to_a
    assign_planning_states_context!

    respond_to(&:js)
  end

  def reapply
    authorize! :update, @planning

    respond_to do |format|
      if @planning.reapply_state!(@planning_state)
        prepare_planning_show_json!
        format.json { render template: 'plannings/show', formats: [:json] }
      else
        format.json { render json: { error: t('plannings.states.reapply_failed') }, status: :unprocessable_entity }
      end
    end
  end

  def pin
    authorize! :update, @planning

    pinned = ValueToBoolean.value_to_boolean(params[:pinned])
    if pinned &&
       PlanningState.pinned_count_for(@planning.id) >= PlanningState::MAX_PINNED &&
       !@planning_state.pinned?
      respond_to do |format|
        format.json do
          render json: { error: t('plannings.states.pin_limit_reached') }, status: :unprocessable_entity
        end
      end
      return
    end

    @planning_state.update!(pinned: pinned)

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  private

  def set_planning
    @planning = current_user.customer.plannings.where(id: params[:planning_id]).preload_route_details.first!
  end

  def set_planning_state
    @planning_state = @planning.planning_states.find(params[:id])
  end

  def prepare_planning_show_json!
    @planning = Planning.where(id: @planning.id).preload_routes_without_stops.first!
    default_with_stops = PlanningStopsPreload.preload_mode(@planning) == :full
    @with_stops = ValueToBoolean.value_to_boolean(params[:with_stops], default_with_stops)
    @routes = if @with_stops
      @planning.routes.available.includes_destinations_and_stores.includes_vehicle_usages
    else
      @planning.routes.available.includes_vehicle_usages
    end
    @with_devices = true
  end

  def enforce_planning_states_operation!
    if %w[index].include?(action_name)
      deny_unless_operation_visible!(:planning, 'planning_states')
    else
      deny_unless_operation_usable!(:planning, 'planning_states')
    end
  rescue PreferencesAuthorization::Forbidden
    head :forbidden
  end

  def assign_planning_states_context!
    @reference_statistics = @planning.route_data_statistics
    @current_visit_ids = current_planning_visit_ids
    @pinned_count = @planning_states.count(&:pinned)
    @prefered_unit = current_user.prefered_unit
  end

  def current_planning_visit_ids
    @planning.routes.flat_map(&:stops).grep(StopVisit).map(&:visit_id).sort
  end
end
