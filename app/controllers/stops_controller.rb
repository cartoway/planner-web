# Copyright © Mapotempo, 2017
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

class StopsController < ApplicationController
  include PlanningsHelper
  include PlanningToolbarPermissions

  before_action :authenticate_user!, except: [:edit, :update]
  before_action :set_route_context, only: [:create_store_reload, :create_regulatory_rest, :destroy]
  before_action :authenticate_driver!, only: [:edit, :update]
  before_action :set_stop, only: [:show, :edit, :update] # Before load_and_authorize_resource

  load_and_authorize_resource # Load resource except for show action

  def create_store_reload
    if @route && params[:store_reload_id]
      @store_reload = current_user.customer.store_reloads.find(params[:store_reload_id])
      respond_to do |format|
        if @route.add_store_reload(@store_reload) && @route.save && load_planning_with_scope && @planning.compute_saved && load_planning_with_scope
          @planning.capture_state!(trigger: 'update_stop')
          format.json { render json: { status: :ok } }
        else
          errors = (@route.errors&.full_messages || []) + (@planning&.errors&.full_messages || [])
          format.json { render json: { status: :unprocessable_entity, error: errors }, status: :unprocessable_entity }
        end
      end
    end
  end

  def create_regulatory_rest
    unless @route&.vehicle_usage&.regulatory_rest?
      respond_to do |format|
        format.json {
          render json: {
            status: :unprocessable_entity,
            error: I18n.t('plannings.edit.create_regulatory_rest.error.not_enabled')
          }, status: :unprocessable_entity
        }
      end
      return
    end

    respond_to do |format|
      if @route.add_rest && @route.save && load_planning_with_scope && @planning.compute_saved && load_planning_with_scope
        @planning.capture_state!(trigger: 'update_stop')
        format.json { render json: { status: :ok } }
      else
        errors = (@route.errors&.full_messages || []) + (@planning&.errors&.full_messages || [])
        format.json { render json: { status: :unprocessable_entity, error: errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @route && params[:stop_id]
      stop = @route.stops.find(params[:stop_id])
      respond_to do |format|
        if stop.is_a?(StopStore)
          @route.remove_store_reload(stop) && @route.save!
        elsif stop.is_a?(StopRest) && @route.vehicle_usage&.regulatory_rest?
          @route.remove_rest(stop) && @route.save!
        else
          format.js {
            head :no_content
          }
          return
        end
        if load_planning_with_scope && @planning.compute_saved && load_planning_with_scope
          @planning.capture_state!(trigger: 'update_stop')
          planning_data = JSON.parse(render_to_string(template: 'plannings/show', formats: [:json]), symbolize_names: true)
          route_data = planning_data[:routes].select{ |route| route[:route_id] == @route.id }
          format.js { render partial: 'routes/update', formats: [:js], locals: { updated_routes: route_data, summary: planning_summary(@planning) } }
        else
          errors = @planning.errors.full_messages.size.zero? ? @planning.customer.errors.full_messages : @planning.errors.full_messages
          flash[:error] = errors
          format.js { render partial: 'shared/error_messages', formats: [:js], status: :unprocessable_entity }
        end
      end
    end
  end

  def show
    respond_to do |format|
      @show_isoline = true
      format.json
    end
  end

  def edit
    # Planning mobile is retired — send drivers to the operation route screen.
    operation_stop = OperationStop.executable.find_by(stop_id: @stop.id)
    if operation_stop
      redirect_to mobile_operation_operation_route_path(
        operation_stop.operation_route.operation,
        operation_stop.operation_route,
        driver_token: params[:driver_token]
      )
    else
      head :gone
    end
  end

  def update
    respond_to do |format|
      if @stop.update(stop_params)
        format.json do
          render json: { success: true }
        end
      else
        format.json do
          flash.now[:alert] = I18n.t('stops.error_messages.update.failure')
          render json: { error: I18n.t('stops.error_messages.update.failure') }.to_json,
                status: :unprocessable_entity
        end
      end
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_stop
    if params[:stop_id] || params[:id]
      @stop = Stop.find(params[:stop_id] || params[:id])
    else
      @stop = Stop.find_by route_id: params[:route_id], index: params[:index]
    end
    raise ActiveRecord::RecordNotFound if @stop.nil?

    @route = @stop.route
    @visit = @stop.visit
    @destination = @stop.visit&.destination
  end

  def stop_params
    stop = params.require(:stop)
    return stop.permit if stop[:custom_attributes].blank?

    stop.permit(custom_attributes: RecursiveParamsHelper.permit_recursive(stop[:custom_attributes]))
  end

  def set_route_context
    @manage_planning =
      if request.referer&.match('api-web')
        ApiWeb::V01::PlanningsController.manage
      else
        PlanningsController.manage
      end
    @route = current_user.customer.plannings.find(params[:planning_id])
                         .routes.includes_destinations_and_stores.where(id: params[:route_id]).first!
    @planning = @route.planning
    apply_planning_toolbar_operation_flags!
    @available_store_reloads =
      current_user.customer.stores.flat_map { |store|
        store.store_reloads.map.with_index { |store_reload, index|
          {
            id: store_reload.id,
            name: store_reload.name,
            ref: store_reload.ref,
            icon: store_reload.icon,
            color: store_reload.color,
            index: index + 1
          }
        }
      }.compact
    @with_stops = ValueToBoolean.value_to_boolean(params[:with_stops], true)
    @colors = COLORS_TABLE.dup.unshift(nil)
  end

  def load_planning_with_scope
    @planning = current_user.customer.plannings.where(id: params[:planning_id]).preload_route_details.first!
  end
end
