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
require 'csv'
require 'importer_destinations'

class DestinationsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_destination, only: [:show, :edit, :update, :destroy]
  after_action :warnings, only: [:create, :update]
  around_action :over_max_limit, only: [:create, :duplicate]

  load_and_authorize_resource

  include LinkBack

  def index
    @customer = current_user.customer
    @destinations = if request.format.html? || !@customer.is_editable?
      current_user.customer.destinations.reorder('geocoding_accuracy ASC NULLS LAST').includes([:tags])
    else
      current_user.customer.destinations.reorder('geocoding_accuracy ASC NULLS LAST').includes_visits
    end
    @tags = current_user.customer.tags
    respond_to do |format|
      format.html
      format.json
      format.excel do
        send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
            type: 'text/csv',
            filename: format_filename(t('activerecord.models.destinations.other')) + '.csv',
            disposition: params.key?(:disposition) ? params[:disposition] : 'attachment'
      end
      format.csv do
        response.headers['Content-Disposition'] = 'attachment; filename="' + format_filename(t('activerecord.models.destinations.other')) + '.csv"'
      end
    end
  end

  def show
    # Not for save/update
    # => Allow using different graph
    @customer = current_user.customer
    @destination = Destination.find params[:id] || params[:destination_id]
    respond_to do |format|
      format.json
    end
  end

  def new
    @destination = current_user.customer.destinations.build
    @destination.postalcode = current_user.customer.stores[0].postalcode
    @destination.city = current_user.customer.stores[0].city
  end

  def edit
  end

  def create
    respond_to do |format|
      p = destination_params
      time_with_day_params(params, p, [:time_window_start_1, :time_window_end_1, :time_window_start_2, :time_window_end_2])
      @destination = current_user.customer.destinations.build(p)

      if @destination.save && current_user.customer.save
        format.html { redirect_to link_back || edit_destination_path(@destination), notice: t('activerecord.successful.messages.created', model: @destination.class.model_name.human) }
      else
        flash.now[:error] = @destination.customer.errors.full_messages unless @destination.customer.errors.empty?
        format.html { render action: 'new' }
      end
    end
  end

  def update
    respond_to do |format|
      Destination.transaction do
        p = destination_params
        time_with_day_params(params, p, [:time_window_start_1, :time_window_end_1, :time_window_start_2, :time_window_end_2])
        @destination.assign_attributes(p)

        if @destination.save && @destination.customer.save
          format.html { redirect_to link_back || edit_destination_path(@destination), notice: t('activerecord.successful.messages.updated', model: @destination.class.model_name.human) }
        else
          flash.now[:error] = @destination.customer.errors.full_messages unless @destination.customer.errors.empty?
          format.html { render action: 'edit' }
        end
      end
    end
  end

  def destroy
    @destination.destroy
    respond_to do |format|
      format.html { redirect_to destinations_url }
    end
  end

  def import_template
    respond_to do |format|
      format.excel do
        send_data Iconv.iconv("#{I18n.t('encoding')}//translit//ignore", 'utf-8', render_to_string).join(''),
            type: 'text/csv',
            filename: format_filename('import_template.csv'),
            disposition: params.key?(:disposition) ? params[:disposition] : 'attachment'
      end
      format.csv
    end
  end

  def import
    @columns_default = current_user.customer&.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')

    @import_csv = ImportCsv.new(column_def: @columns_default)
    @import_tomtom = ImportTomtom.new
  end

  def upload_csv
    @columns_default = current_user.customer&.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')

    respond_to do |format|
      @importer = ImporterDestinations.new(current_user.customer)
      @import_csv = ImportCsv.new(import_csv_params.merge(importer: @importer, content_code: :html, column_def: @columns_default))
      if @import_csv.valid? && @import_csv.import
        if @import_csv.importer.plannings.size == 1 && !current_user.customer.job_destination_geocoding
          format.html { redirect_to edit_planning_url(@import_csv.importer.plannings.last) }
        elsif @import_csv.importer.plannings.size > 1 && !current_user.customer.job_destination_geocoding
          format.html { redirect_to plannings_url }
        else
          format.html { redirect_to action: 'index' }
        end
      else
        @import_tomtom = ImportTomtom.new
        format.html { render action: 'import' }
      end
    end
  end

  def upload_tomtom
    @import_tomtom = ImportTomtom.new import_tomtom_params.merge(importer: ImporterDestinations.new(current_user.customer), customer: current_user.customer, content_code: :html)
    if current_user.customer.device.configured?(:tomtom) && @import_tomtom.valid? && @import_tomtom.import
      flash[:warning] = @import_tomtom.warnings.join(', ') if @import_tomtom.warnings.any?
      redirect_to destinations_path, notice: t('.success')
    else
      @import_csv = ImportCsv.new
      render action: :import
    end
  rescue DeviceServiceError => e
    redirect_to destination_import_path, alert: e.message
  end

  def clear
    Destination.transaction do
      current_user.customer.delete_all_destinations
    end
    respond_to do |format|
      format.html { redirect_to action: 'index' }
    end
  end

  private

  def time_with_day_params(params, local_params, times)
    return unless local_params[:visits_attributes]

    if local_params[:visits_attributes].is_a?(Array)
      local_params[:visits_attributes].each_with_index do |_, i|
        times.each do |time|
          local_params[:visits_attributes][i][time] = ChronicDuration.parse("#{params[:destination][:visits_attributes][i]["#{time}_day".to_sym]} days and #{local_params[:visits_attributes][i][time].tr(':', 'h')}min", keep_zero: true) unless params[:destination][:visits_attributes][i]["#{time}_day".to_sym].to_s.empty? || local_params[:visits_attributes][i][time].to_s.empty?
        end
      end
    else
      local_params[:visits_attributes].each_pair do |k, valu|
        times.each do |time|
          next if params[:destination][:visits_attributes][k]["#{time}_day".to_sym].to_s.empty? ||
                  local_params[:visits_attributes][k][time].to_s.empty?

          local_params[:visits_attributes][k][time] =
            ChronicDuration.parse(
              "#{params[:destination][:visits_attributes][k]["#{time}_day".to_sym]} days and #{local_params[:visits_attributes][k][time].tr(':', 'h')}min",
              keep_zero: true
            )
        end
      end
    end
  end

  # Use callbacks to share common setup or constraints between actions.
  def set_destination
    @destination = current_user.customer.destinations.find params[:id] || params[:destination_id]
  end

  def warnings
    flash[:warning] = @destination.warnings.join(', ') if @destination.warnings && @destination.warnings.any?
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def destination_params
    # Deals with deprecated quantity
    params[:visits_attributes]&.each{ |p|
      if !p[:quantities] && p[:quantity] && !current_user.customer.deliverable_units.empty?
        p[:quantities] = { current_user.customer.deliverable_units[0].id => p.delete(:quantity) }
      end
    }

    o = params.require(:destination).permit(
      :ref,
      :name,
      :street,
      :detail,
      :postalcode,
      :city,
      :state,
      :country,
      :lat,
      :lng,
      :phone_number,
      :comment,
      :geocoding_accuracy,
      :geocoding_level,
      :geocoder_version,
      :geocoded_at,
      tag_ids: [],
      visits_attributes: [
        :id,
        :ref,
        :duration,
        :time_window_start_1,
        :time_window_end_1,
        :time_window_start_2,
        :time_window_end_2,
        :priority,
        :force_position,
        :_destroy,
        tag_ids: [],
        quantities: current_user.customer.deliverable_units.map{ |du| du.id.to_s },
        quantities_operations: current_user.customer.deliverable_units.map{ |du| du.id.to_s }
      ]
    )
    o[:visits_attributes].each do |_k, v|
      v[:quantities_operations].each{ |k, qo|
        v[:quantities][k] = "#{-v[:quantities][k].to_f}" if v[:quantities][k].to_f > 0 && qo.to_sym == :empty
      } if v && v[:quantities_operations]
    end if o[:visits_attributes]
    o
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def import_csv_params
    params.require(:import_csv).permit(
      :replace,
      :file,
      :delete_plannings,
      column_def: @importer.columns.keys
    )
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def import_tomtom_params
    params.require(:import_tomtom).permit(:replace)
  end
end
