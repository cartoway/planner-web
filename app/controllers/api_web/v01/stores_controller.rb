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
class ApiWeb::V01::StoresController < ApiWeb::V01::ApiWebController
  skip_before_action :verify_authenticity_token # because rails waits for a form token with POST
  before_action :set_store, only: [:edit_position, :update_position, :show]
  authorize_resource

  def index
    @customer = current_user.customer
    @stores = if params.key?(:ids)
      ids = params[:ids].split(',')
      current_user.customer.stores.where(ParseIdsRefs.where(Store, ids))
    else
      respond_to do |format|
        format.html do
          nil
        end
        format.json do
          current_user.customer.stores.load
        end
      end
    end
    @tags = current_user.customer.tags
    @method = request.method_symbol
  end

  def show
    respond_to do |format|
      @show_isoline = false
      format.json
    end
  end

  def edit_position
  end

  def update_position
    respond_to do |format|
      Store.transaction do
        if @store.update(store_params) && @store.customer.save
          format.html { redirect_to api_web_v01_edit_position_store_path(@store), notice: t('activerecord.successful.messages.updated', model: @store.class.model_name.human) }
        else
          format.html { render action: 'edit_position' }
        end
      end
    end
  end

  def by_distance
    @customer = current_user.customer
    @position = OpenStruct.new(lat: Float(params[:lat]), lng: Float(params[:lng]))
    @stores = @customer.stores_by_distance(@position, Integer(params[:n]))
  end

  private

  # Use callbacks to share common setup or constraints between actions.
  def set_store
    @store = Store.find(params[:id] || params[:store_id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def store_params
    params.require(:store).permit(:name, :street, :postalcode, :city, :country, :lat, :lng, :open, :close)
  end
end
