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
  before_action :set_planning_state, only: [:reapply, :destroy, :pin]

  include PlanningsHelper
  include ApplicationHelper
  include PlanningStatesHelper
  include PlanningToolbarPermissions
  include PreferencesAuthorization

  before_action :enforce_planning_states_operation!

  def index
    authorize! :read, @planning
    @planning_states = @planning.planning_states.to_a

    respond_to do |format|
      format.json { render json: planning_states_json }
    end
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

  def destroy
    authorize! :update, @planning
    @planning_state.destroy!

    respond_to do |format|
      format.json { head :no_content }
    end
  end

  def pin
    authorize! :update, @planning

    pinned = ValueToBoolean.value_to_boolean(params[:pinned])
    if pinned &&
       PlanningState.pinned_count_for(@planning.id, @planning_state.category) >= PlanningState::MAX_PINNED_PER_GROUP &&
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

  def planning_states_json
    reference_statistics = @planning.route_data_statistics
    states_by_category = @planning_states.group_by(&:category)

    PlanningState::CATEGORIES.filter_map do |category|
      states = states_by_category[category]
      next if states.blank?

      pinned_count = states.count(&:pinned)

      {
        category: category,
        category_label: t("plannings.states.categories.#{category}"),
        max_pinned: PlanningState::MAX_PINNED_PER_GROUP,
        pinned_count: pinned_count,
        states: states.map { |state| planning_state_json(state, reference_statistics: reference_statistics) }
      }
    end
  end

  def planning_state_json(state, reference_statistics:)
    statistics = state.statistics || {}
    prefered_unit = current_user.prefered_unit

    {
      id: state.id,
      category: state.category,
      pinned: state.pinned,
      captured_at: state.captured_at,
      trigger: state.trigger,
      trigger_label: t("plannings.states.triggers.#{state.trigger}", default: state.trigger),
      captured_at_label: I18n.l(state.captured_at, format: :long),
      statistics_html: planning_state_statistics_html(
        statistics,
        prefered_unit: prefered_unit,
        reference_statistics: reference_statistics
      ),
      statistics: statistics
    }
  end
end
