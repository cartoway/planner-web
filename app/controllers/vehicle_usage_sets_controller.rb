# Copyright © Mapotempo, 2013-2014
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
class VehicleUsageSetsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_vehicle_usage_set, only: [:show, :edit, :update, :destroy, :duplicate]
  around_action :over_max_limit, only: [:create, :duplicate]

  load_and_authorize_resource

  include LinkBack

  def index
    @customer = current_user.customer
    @vehicle_usage_sets = @customer.vehicle_usage_sets.includes([:vehicle_usages, {vehicle_usages: [vehicle: [:router, :customer]]}])
  end

  def show
    respond_to do |format|
      format.html
      format.excel do
        send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
                  type: 'text/csv',
                  filename: format_filename(t('activerecord.models.vehicle_usage_sets.other')) + '.csv',
                  disposition: params.key?(:disposition) ? params[:disposition] : 'attachment'
      end
      format.csv do
        response.headers['Content-Disposition'] = 'attachment; filename="' + format_filename(t('activerecord.models.vehicle_usage_sets.other')) + '.csv"'
      end
    end
  end

  def new
    @vehicle_usage_set = current_user.customer.vehicle_usage_sets.build
    @vehicle_usage_set.store_start = current_user.customer.stores[0]
    @vehicle_usage_set.store_stop = current_user.customer.stores[0]
  end

  def edit
  end

  def create
    respond_to do |format|
      p = vehicle_usage_set_params
      time_with_day_params(params, p, [:time_window_start, :time_window_end, :rest_start, :rest_stop, :work_time, :max_ride_duration, :store_duration])
      @vehicle_usage_set = current_user.customer.vehicle_usage_sets.build(p)

      if @vehicle_usage_set.save
        format.html { redirect_to vehicle_usage_sets_path, notice: t('activerecord.successful.messages.created', model: @vehicle_usage_set.class.model_name.human) }
      else
        format.html { render action: 'new' }
      end
    end
  end

  def update
    respond_to do |format|
      p = vehicle_usage_set_params
      time_with_day_params(params, p, [:time_window_start, :time_window_end, :rest_start, :rest_stop, :work_time, :max_ride_duration, :store_duration])
      @vehicle_usage_set.assign_attributes(p)

      if @vehicle_usage_set.save
        format.html { redirect_to link_back || vehicle_usage_sets_path, notice: t('activerecord.successful.messages.updated', model: @vehicle_usage_set.class.model_name.human) }
      else
        format.html { render action: 'edit' }
      end
    end
  end

  def destroy
    respond_to do |format|
      if @vehicle_usage_set.destroy
        format.html { redirect_to vehicle_usage_sets_url }
      else
        flash[:error] = @vehicle_usage_set.errors.full_messages
        format.html { render action: 'index' }
      end
    end
  end

  def destroy_multiple
    if params['disable_multiple']
      activate_multiple_vehicle_usage(params['disable_multiple'], false)
    elsif params['enable_multiple']
      activate_multiple_vehicle_usage(params['enable_multiple'], true)
    else
      VehicleUsageSet.transaction do
        if params['vehicle_usage_sets']
          ids = params['vehicle_usage_sets'].keys.collect { |i| Integer(i) }
          current_user.customer.vehicle_usage_sets.select { |v| ids.include?(v.id) }.each(&:destroy)
        end
        respond_to do |format|
          format.html { redirect_to vehicle_usage_sets_url }
        end
      end
    end
  end

  def duplicate
    respond_to do |format|
      @vehicle_usage_set = @vehicle_usage_set.duplicate
      @vehicle_usage_set.save! validate: Planner::Application.config.validate_during_duplication
      format.html { redirect_to edit_vehicle_usage_set_path(@vehicle_usage_set), notice: t('activerecord.successful.messages.updated', model: @vehicle_usage_set.class.model_name.human) }
    end
  end

  def import_template
    respond_to do |format|
      format.excel do
        send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
                  type: 'text/csv',
                  filename: format_filename('import_template.csv')
      end
      format.csv
    end
  end

  def import
    @customer = current_user.customer
    @import_csv = ImportCsv.new
  end

  def upload_csv
    respond_to do |format|
      @customer = current_user.customer
      @import_csv = ImportCsv.new(import_csv_params.merge(importer: ImporterVehicleUsageSets.new(current_user.customer)))
      if @import_csv.valid? && @import_csv.import
        format.html { redirect_to action: 'index' }
      else
        format.html { render action: 'import' }
      end
    end
  end

  private

  def activate_multiple_vehicle_usage(vehicle_usage_set_id, activate)
    VehicleUsageSet.transaction do
      if params['vehicle_usages']
        vehicle_usage_ids = []
        params['vehicle_usages'][vehicle_usage_set_id].each_pair{ |key, value| vehicle_usage_ids << key.to_i if value == 'on' }
        current_user.customer.vehicle_usage_sets.find(vehicle_usage_set_id).vehicle_usages.each{ |vu|
          vu.update(active: activate) if vehicle_usage_ids.include?(vu.id)
        }
      end
      respond_to do |format|
        format.html { redirect_to vehicle_usage_sets_url }
      end
    end
  end

  def time_with_day_params(params, local_params, times)
    times.each do |time|
      local_params[time] = ChronicDuration.parse("#{params[:vehicle_usage_set]["#{time}_day".to_sym]} days and #{local_params[time].tr(':', 'h')}min", keep_zero: true) unless params[:vehicle_usage_set]["#{time}_day".to_sym].to_s.empty? || local_params[time].to_s.empty?
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_vehicle_usage_set
    @vehicle_usage_set = current_user.customer.vehicle_usage_sets.find params[:id] || params[:vehicle_usage_set_id]
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def vehicle_usage_set_params
    parameters = params.require(:vehicle_usage_set).permit(:name,
                                              :cost_distance,
                                              :cost_fixed,
                                              :cost_time,
                                              :time_window_start,
                                              :time_window_end,
                                              :store_start_id,
                                              :store_stop_id,
                                              :store_duration,
                                              :rest_start,
                                              :rest_stop,
                                              :rest_duration,
                                              :store_rest_id,
                                              :service_time_start,
                                              :service_time_end,
                                              :work_time,
                                              :max_distance,
                                              :max_ride_distance,
                                              :max_ride_duration)
    parameters[:max_distance] = DistanceUnits.distance_to_meters(parameters[:max_distance], @current_user.prefered_unit) if parameters.key?(:max_distance)
    parameters[:max_ride_distance] = DistanceUnits.distance_to_meters(parameters[:max_ride_distance], @current_user.prefered_unit) if parameters.key?(:max_ride_distance)
    parameters
  end

  def import_csv_params
    params.require(:import_csv).permit(:replace,
                                       :replace_vehicles,
                                       :file,
                                       column_def: ImporterVehicleUsageSets.new(current_user.customer).columns.keys)
  end
end
