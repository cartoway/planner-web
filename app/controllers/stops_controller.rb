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
  before_action :authenticate_user!, except: [:edit, :update]
  before_action :authenticate_driver!, only: [:edit, :update]
  before_action :set_stop, only: [:show, :edit, :update] # Before load_and_authorize_resource

  load_and_authorize_resource # Load resource except for show action

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
    if @stop.update(stop_params)
      if request.xhr?
        render json: { success: true }
      end
    else
      format.json do
        flash.now[:alert] = I18n.t('stops.error_messages.update.failure')
        render json:   { error: I18n.t('stops.error_messages.update.failure') }.to_json,
               status: :unprocessable_entity
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
    @route = @stop.route
    @visit = @stop.visit
    @destination = @stop.visit.destination
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def stop_params
    params.require(:stop).permit(
      :status,
      :status_updated_at
    )
  end
end
