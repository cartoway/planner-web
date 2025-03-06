# Copyright © Mapotempo, 2013-2015
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
class ZoningsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_zoning, only: [:show, :edit, :update, :destroy, :duplicate, :automatic, :from_planning, :isochrone, :isodistance]
  before_action :set_planning, only: [:show, :edit, :new, :automatic, :from_planning]
  before_action :manage_zoning
  before_action :set_deliverable_unit_icons, only: [:edit, :automatic, :from_planning]
  around_action :includes_destinations, only: [:show, :edit, :update, :automatic, :from_planning]
  around_action :over_max_limit, only: [:create, :duplicate]

  load_and_authorize_resource

  include CustomersHelper
  include LinkBack

  def index
    @zonings = current_user.customer.zonings
  end

  def show
    respond_to do |format|
      format.excel do
        @customer = current_user.customer
        if @planning
          @destinations = @planning.routes.flat_map{ |route| route.stops.only_stop_visits.flat_map{ |stop| stop.visit.destination }}.uniq
        elsif !@destinations
          @destinations = @customer.destinations.includes_visits
        end

        # TODO: Use postgis to compute included destinations
        @zoned_destinations = @destinations&.map{ |destination|
          destination_zones = @zoning.zones.select{ |zone|
            zone.inside_distance(destination.lat, destination.lng)
          }.map{ |zone| zone.name || zone.id }
          [destination, destination_zones]
        }
        send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
            type: 'text/csv',
            filename: format_filename(t('activerecord.models.destinations.other')) + '.csv',
            disposition: params.key?(:disposition) ? params[:disposition] : 'attachment'
      end
    end
  end

  def new
    @zoning = current_user.customer.zonings.build
    @plannings = current_user.customer.plannings
  end

  def edit
    @vehicle_usage_set = @planning ? @planning.vehicle_usage_set : @zoning.customer.vehicle_usage_sets[0]
    capabilities
  end

  def create
    respond_to do |format|
      @zoning = current_user.customer.zonings.build(zoning_params)
      if @zoning.save
        format.html { redirect_to edit_zoning_path(@zoning, planning_id: params.key?(:planning_id) ? params[:planning_id] : nil), notice: t('activerecord.successful.messages.created', model: @zoning.class.model_name.human) }
      else
        @planning = params.key?(:planning_id) ? current_user.customer.plannings.find(params[:planning_id]) : nil
        format.html { render action: 'new' }
      end
    end
  end

  def update
    respond_to do |format|
      if @zoning.update(zoning_params)
        format.html { redirect_to link_back || edit_zoning_path(@zoning, planning_id: params.key?(:planning_id) ? params[:planning_id] : nil), notice: t('activerecord.successful.messages.updated', model: @zoning.class.model_name.human) }
      else
        @planning = params.key?(:planning_id) ? current_user.customer.plannings.find(params[:planning_id]) : nil
        capabilities
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    @zoning.destroy
    respond_to do |format|
      format.html { redirect_to zonings_url }
    end
  end

  def destroy_multiple
    Zoning.transaction do
      if params['zonings']
        ids = params['zonings'].keys.collect{ |i| Integer(i) }
        current_user.customer.zonings.select{ |zoning| ids.include?(zoning.id) }.each(&:destroy)
      end
      respond_to do |format|
        format.html { redirect_to zonings_url }
      end
    end
  end

  def duplicate
    respond_to do |format|
      @zoning = @zoning.duplicate
      @zoning.save! validate: Planner::Application.config.validate_during_duplication
      format.html { redirect_to edit_zoning_path(@zoning), notice: t('activerecord.successful.messages.updated', model: @zoning.class.model_name.human) }
    end
  end

  def automatic
    respond_to do |format|
      n = params[:n].to_i if params[:n]
      hide_out_of_route = params[:hide_out_of_route].to_i == 1
      @zoning.automatic_clustering @planning, n, !hide_out_of_route
      @zoning.save!
      format.json { render action: 'edit' }
    end
  end

  def from_planning
    respond_to do |format|
      if @planning
        @zoning.from_planning(@planning)
        @zoning.save!
      end
      format.json { render action: 'edit' }
    end
  end

  def isochrone
    respond_to do |format|
      size = params.key?(:size) ? Integer(params[:size]) * 60 : 600
      vehicle_usage_set_id = Integer(params[:vehicle_usage_set_id])
      vehicle_usage_set = current_user.customer.vehicle_usage_sets.to_a.find{ |vehicle_usage_set| vehicle_usage_set.id == vehicle_usage_set_id }
      if size && vehicle_usage_set
        @zoning.isochrones(size, vehicle_usage_set, params[:departure_date].blank? ? Date.today : Date.parse(params[:departure_date]))
        @zoning.save!
      end
      format.json { render action: 'edit' }
    end
  end

  def isodistance
    respond_to do |format|
      size = params.key?(:size) ? Float(params[:size].tr(',', '.')) * 1000 : 1000
      vehicle_usage_set_id = Integer(params[:vehicle_usage_set_id])
      vehicle_usage_set = current_user.customer.vehicle_usage_sets.to_a.find{ |vehicle_usage_set| vehicle_usage_set.id == vehicle_usage_set_id }
      if size && vehicle_usage_set
        @zoning.prefered_unit = current_user.prefered_unit
        @zoning.isodistances(size, vehicle_usage_set, params[:departure_date].blank? ? Date.today : Date.parse(params[:departure_date]))
        @zoning.save!
      end
      format.json { render action: 'edit' }
    end
  end

  def self.manage
    Hash[[:edit, :organize].map{ |v| ["manage_#{v}".to_sym, true] }]
  end

  private

  def capabilities
    vehicle_usage_sets = @planning ? [@planning.vehicle_usage_set] : @zoning.customer.vehicle_usage_sets
    @isochrone = vehicle_usage_sets.collect { |vehicle_usage_set|
      [vehicle_usage_set, @zoning.isochrone?(vehicle_usage_set)]
    }
    @isodistance = vehicle_usage_sets.collect { |vehicle_usage_set|
      [vehicle_usage_set, @zoning.isodistance?(vehicle_usage_set)]
    }
    @isoline_need_time = vehicle_usage_sets.map { |vehicle_usage_set|
      [vehicle_usage_set, vehicle_usage_set.vehicle_usages.any?{ |vu| vu.vehicle.default_router_options['traffic'] }]
    }
  end

  def set_deliverable_unit_icons
    @deliverable_unit_icons = deliverable_unit_icons(current_user.customer)
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_zoning
    @zoning = current_user.customer.zonings.includes(customer: [vehicle_usage_sets: [vehicle_usages: :vehicle]]).find(params[:id] || params[:zoning_id])
  end

  def set_planning
    @planning = params.key?(:planning_id) && !params[:planning_id].empty? ? current_user.customer.plannings.preload_route_details.find(params[:planning_id]) : nil
  end

  def includes_destinations
    Route.includes_destinations.scoping do
      yield
    end
  end

  def manage_zoning
    @manage_zoning = ZoningsController.manage
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def zoning_params
    params[:zoning][:zones_attributes].each{ |zone|
      zone[:speed_multiplier] = zone[:avoid_zone] ? 0 : 1
    } if params[:zoning][:zones_attributes]
    params.require(:zoning).permit(:name, zones_attributes: [:id, :name, :polygon, :_destroy, :vehicle_id, :speed_multiplier])
  end
end
