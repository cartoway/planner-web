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
class ApiWeb::V01::ZoningsController < ApiWeb::V01::ApiWebController
  skip_before_action :verify_authenticity_token # because rails waits for a form token with POST
  load_and_authorize_resource
  before_action :manage_zoning
  around_action :includes_destinations

  def edit
    capabilities
  end

  def update
    respond_to do |format|
      if @zoning.update_attributes(zoning_params) && @zoning.save
        @zoning.errors.add(:base, 'test')
        format.html { redirect_to api_web_v01_edit_zoning_path(@zoning), notice: t('activerecord.successful.messages.updated', model: @zoning.class.model_name.human) }
      else
        capabilities
        format.html { render action: 'edit' }
      end
    end
  end

  def self.manage
    Hash[[:edit, :organize].map{ |v| ["manage_#{v}".to_sym, true] }]
  end

  private

  def capabilities
    @isochrone = []
    @isodistance = []
    @isoline_need_time = []
  end

  # Use callbacks to share common setup or constraints between actions.
  # rights should be checked before thanks to CanCan::Ability
  def manage_zoning
    @manage_zoning = ApiWeb::V01::ZoningsController.manage
  end

  def includes_destinations
    Route.includes_destinations.scoping do
      yield
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def zoning_params
    params[:zoning] ||= {id: params[:id]} # Require not empty if none zone
    params[:zoning][:zones_attributes].each{ |zone|
      zone[:speed_multiplier] = zone[:avoid_zone] ? 0 : 1
    } if params[:zoning][:zones_attributes]
    params.require(:zoning).permit(:name, zones_attributes: [:id, :name, :polygon, :_destroy, :vehicle_id, :speed_multiplier])
  end
end
