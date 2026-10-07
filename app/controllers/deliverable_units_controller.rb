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
require 'font_awesome'

class DeliverableUnitsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_deliverable_unit, only: [:edit, :update, :destroy]
  before_action :icons_table, except: [:index]

  include PreferencesAuthorization
  include V2Layout
  before_action -> { deny_unless_form_create!(:deliverable_units) }, only: [:create]
  before_action -> { deny_unless_form_update!(:deliverable_units) }, only: [:update, :destroy, :destroy_multiple]

  load_and_authorize_resource

  def index
    @deliverable_units = current_user.customer.deliverable_units
    render_page 'v2/deliverable_units/index' if layout_v2?
  end

  def new
    @deliverable_unit = current_user.customer.deliverable_units.build
    render_form_or_list('new_sidebar', 'v2/deliverable_units/index', deliverable_units_path) { @deliverable_units = current_user.customer.deliverable_units }
  end

  def edit
    render_form_or_list('edit_sidebar', 'v2/deliverable_units/index', deliverable_units_path) { @deliverable_units = current_user.customer.deliverable_units }
  end

  def create
    respond_to do |format|
      DeliverableUnit.transaction do
        @deliverable_unit = current_user.customer.deliverable_units.build(deliverable_unit_params)
        if current_user.customer.save
          format.turbo_stream { render_streams(deliverable_unit_append_stream) }
          format.html do
            if sidebar_submit?
              render_close_sidebar
            else
              redirect_to deliverable_units_path, notice: t('activerecord.successful.messages.created', model: @deliverable_unit.class.model_name.human)
            end
          end
        else
          format.html do
            if sidebar_submit?
              render 'new_sidebar', layout: false, status: :unprocessable_entity
            else
              render action: 'new'
            end
          end
          format.turbo_stream { render_sidebar_stream('new_sidebar') }
        end
      end
    end
  end

  def update
    respond_to do |format|
      if @deliverable_unit.update(deliverable_unit_params) && @deliverable_unit.customer.save
        format.turbo_stream { render_streams(deliverable_unit_replace_stream) }
        format.html do
          if sidebar_submit?
            render_close_sidebar
          else
            redirect_to deliverable_units_path, notice: t('activerecord.successful.messages.updated', model: @deliverable_unit.class.model_name.human)
          end
        end
      else
        format.html do
          if sidebar_submit?
            render 'edit_sidebar', layout: false, status: :unprocessable_entity
          else
            render action: 'edit'
          end
        end
        format.turbo_stream { render_sidebar_stream('edit_sidebar') }
      end
    end
  end

  def destroy
    destroyed = @deliverable_unit && current_user.customer.deliverable_units.delete(@deliverable_unit) && current_user.customer.save
    respond_to do |format|
      if destroyed
        format.turbo_stream { render_streams(stream_remove(@deliverable_unit), close_sidebar: false) }
      end
      format.html { redirect_to deliverable_units_url, status: :see_other }
    end
  end

  def destroy_multiple
    DeliverableUnit.transaction do
      if params['deliverable_units']
        ids = params['deliverable_units'].keys.collect{ |i| Integer(i) }
        current_user.customer.deliverable_units.select{ |deliverable_unit| ids.include?(deliverable_unit.id) }.each(&:destroy)
        current_user.customer.save
      end
      respond_to do |format|
        format.html { redirect_to deliverable_units_url, status: :see_other }
      end
    end
  end

  private

  def deliverable_unit_row_locals
    {
      deliverable_unit: @deliverable_unit,
      can_destroy: helpers.current_user_form_destroy_enabled?(:deliverable_units)
    }
  end

  def deliverable_unit_replace_stream
    stream_replace(@deliverable_unit, partial: 'v2/deliverable_units/list_row', locals: deliverable_unit_row_locals)
  end

  def deliverable_unit_append_stream
    stream_append('deliverable-units-list', partial: 'v2/deliverable_units/list_row', locals: deliverable_unit_row_locals)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_deliverable_unit
    id = params[:id] || params[:deliverable_unit_id]
    @deliverable_unit = if current_user.customer
      current_user.customer.deliverable_units.find(id)
    else
      DeliverableUnit.find(id)
    end
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def deliverable_unit_params
    params.require(:deliverable_unit).permit(:label, :ref, :default_pickup, :default_delivery, :default_capacity, :optimization_overload_multiplier, :icon)
  end

  def icons_table
    @grouped_icons ||= [FontAwesome::ICONS_TABLE_UNIT, (FontAwesome::ICONS_TABLE - FontAwesome::ICONS_TABLE_UNIT)]
  end
end
