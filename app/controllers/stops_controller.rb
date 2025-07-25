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

  before_action :authenticate_user!, except: [:edit, :update]
  before_action :set_planning_and_route_context, only: [:create_store, :destroy]
  before_action :authenticate_driver!, only: [:edit, :update]
  before_action :set_stop, only: [:show, :edit, :update] # Before load_and_authorize_resource

  load_and_authorize_resource # Load resource except for show action

  def create_store
    if @route && params[:store_id]
      @store = current_user.customer.stores.find(params[:store_id])
      @route.add_store(@store)
      respond_to do |format|
        if @planning.compute_saved
          format.json { render json: { status: :ok } }
        else
          errors = @planning.errors.full_messages.size.zero? ? @planning.customer.errors.full_messages : @planning.errors.full_messages
          format.json { render json: { status: :unprocessable_entity, error: errors }, status: :unprocessable_entity }
        end
      end
    end
  end

  def destroy
    if @route && params[:stop_id]
      stop = @route.stops.find(params[:stop_id])

      respond_to do |format|
        if stop.is_a?(StopStore)
          @route.remove_store(stop)
        else
          format.js {
            head :no_content
          }
        end
        if @planning.compute_saved
          planning_data = JSON.parse(render_to_string(template: 'plannings/show.json.jbuilder'), symbolize_names: true)
          format.js { render partial: 'routes/update.js.erb', locals: { updated_routes: planning_data[:routes], summary: planning_summary(@planning) } }
        else
          errors = @planning.errors.full_messages.size.zero? ? @planning.customer.errors.full_messages : @planning.errors.full_messages
          flash[:error] = errors
          format.js { render partial: 'shared/error_messages.js.erb', status: :unprocessable_entity }
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
    respond_to do |format|
      format.html { render 'stops/edit', layout: 'mobile' }
    end
  end

  def update
    if stop_params[:status_updated_at].blank? || DateTime.parse(stop_params[:status_updated_at]) > (@stop.status_updated_at || 0)
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
    else
      raise Exceptions::OutdatedRequestError
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
    @route = @stop.route
    @visit = @stop.visit
    @destination = @stop.visit&.destination
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def stop_params
    params.require(:stop).permit(
      :status,
      :status_updated_at,
      custom_attributes: RecursiveParamsHelper.permit_recursive(params['stop']['custom_attributes'])
    )
  end

  def set_planning_and_route_context
    @manage_planning =
      if request.referer&.match('api-web')
        @callback_button = true
        ApiWeb::V01::PlanningsController.manage
      else
        PlanningsController.manage
      end
    @available_stores = current_user.customer.stores.map { |store| { id: store.id, name: store.name, ref: store.ref, icon: store.icon, color: store.color } }
    @callback_button = true
    @with_stops = ValueToBoolean.value_to_boolean(params[:with_stops], true)
    @colors = COLORS_TABLE.dup.unshift(nil)
    @planning = current_user.customer.plannings.where(id: params[:planning_id]).preload_routes_without_stops.first!
    @route = @planning.routes.find(params[:route_id])
  end
end
