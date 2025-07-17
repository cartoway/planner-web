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
  before_action :set_custom_attributes, only: [:show, :edit, :update, :destroy, :create, :new]
  after_action :warnings, only: [:create, :update]
  around_action :over_max_limit, only: [:create, :duplicate]

  load_and_authorize_resource

  include LinkBack

  def index
    @customer = current_user.customer
    @destinations = if request.format.html? || !@customer.is_editable?
      current_user.customer.destinations.reorder(Arel.sql("CASE WHEN lat IS NULL THEN 0 ELSE 1 END, geocoding_accuracy ASC NULLS LAST")).includes([:tags])
    else
      current_user.customer.destinations.reorder(Arel.sql("CASE WHEN lat IS NULL THEN 0 ELSE 1 END, geocoding_accuracy ASC NULLS LAST")).includes_visits
    end
    @tags = current_user.customer.tags
    respond_to do |format|
      format.html
      format.json
      format.excel do
        send_data render_to_string.encode(I18n.t('encoding'), invalid: :replace, undef: :replace, replace: ''),
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
        send_data render_to_string.encode(I18n.t('encoding'), invalid: :replace, undef: :replace, replace: ''),
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
    respond_to do |format|
      @importer = ImporterDestinations.new(current_user.customer)
      @columns_default = (current_user.customer&.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef') || {}).merge(import_csv_params[:column_def] || {})
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

  def set_custom_attributes
    @visit_custom_attributes = current_user.customer.custom_attributes.for_visit
  end

  def warnings
    flash[:warning] = @destination.warnings.join(', ') if @destination.warnings && @destination.warnings.any?
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def destination_params
    p = params.to_unsafe_h
    # Deals with deprecated quantity
    p[:visits_attributes]&.each{ |p|
      if !p[:deliveries] && p[:quantity] && !current_user.customer.deliverable_units.empty?
        p[:deliveries] = { current_user.customer.deliverable_units[0].id => p.delete(:quantity) }
      end
    }
    if p.dig(:destination, :geocoding_result).to_s.empty?
      p[:destination].delete(:geocoding_result)
    else
      p[:destination][:geocoding_result] = JSON.parse(p[:destination][:geocoding_result])
    end
    p = ActionController::Parameters.new(p)

    p.require(:destination).permit(
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
      :duration,
      :geocoding_accuracy,
      :geocoding_level,
      :geocoder_version,
      :geocoded_at,
      geocoding_result: [
        :free
      ],
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
        :revenue,
        :force_position,
        :_destroy,
        tag_ids: [],
        pickups: current_user.customer.deliverable_units.map{ |du| du.id.to_s },
        deliveries: current_user.customer.deliverable_units.map{ |du| du.id.to_s },
        custom_attributes: current_user.customer.custom_attributes.for_visit.map{ |c_u| c_u.name.to_sym }
      ]
    )
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
