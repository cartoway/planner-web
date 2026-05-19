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
  include LinkBack
  include PreferencesAuthorization

  before_action :authenticate_user!
  before_action :set_destination, only: [:show, :edit, :update, :destroy, :append_visit]
  after_action :warnings, only: [:create, :update]
  around_action :over_max_limit, only: [:create, :duplicate]
  before_action -> { deny_unless_form_update!(:destination) }, only: [:clear]
  before_action -> { deny_unless_form_create!(:destination) }, only: [:upload_csv, :upload_tomtom]

  load_and_authorize_resource

  # visits/_form and v2/visits/_form iterate @visit_custom_attributes; keep it set for v1 and v2 destination flows.
  before_action :assign_visit_custom_attributes, only: [:new, :edit, :create, :update, :append_visit]

  def index
    @customer = current_user.customer
    respond_to do |format|
      format.html do
        per_page = (params[:per_page] || 25).to_i.clamp(1, 100)
        page = [params[:page].to_i, 1].max
        scope = current_user.customer.destinations
                            .reorder('geocoding_accuracy ASC NULLS LAST')
                            .includes([:tags, visits: :tags])

        # Key:value search - badges (from Enter) + live query (from params[:q])
        @active_filters = Array(params[:filters]).compact.map(&:strip).reject(&:blank?)
        conditions = @active_filters.flat_map { |f| DestinationSearchParser.parse(f) }
        conditions += DestinationSearchParser.parse(params[:q]) if params[:q].to_s.strip.present?
        scope = DestinationSearchScope.apply(scope, conditions) if conditions.any?

        @total_count = scope.count
        @destinations = scope.offset((page - 1) * per_page).limit(per_page)
        @tags = current_user.customer.tags
        @pagination = { page: page, per_page: per_page, total: @total_count }
        @search_query = params[:q].to_s.strip

        frame_list = turbo_frame_request? && turbo_frame_request_id == 'destinations_list'

        unless frame_list
          # Map pins for all geolocated rows in the filtered scope (not only the current page), with list page
          # so marker clicks can open the correct pagination and highlight the table row.
          id_to_page = scope.pluck(:id).each_with_index.to_h { |did, idx| [did, (idx / per_page) + 1] }
          @v2_map_destinations = scope.where.not(lat: nil).where.not(lng: nil).pluck(:id, :lat, :lng, :name).map do |did, la, ln, name|
            { id: did, lat: la.to_f, lng: ln.to_f, name: name.to_s, page: id_to_page[did] || 1 }
          end
        end

        if frame_list
          render partial: 'v2/destinations/list_frame', layout: false
        else
          render 'v2/destinations/index', layout: 'v2/layouts/application'
        end
      end
      format.json do
        @destinations = if !@customer.is_editable?
          current_user.customer.destinations.reorder('geocoding_accuracy ASC NULLS LAST').includes([:tags])
        else
          current_user.customer.destinations.reorder('geocoding_accuracy ASC NULLS LAST').includes_visits
        end
        @tags = current_user.customer.tags
        render :index
      end
      format.excel do
        @destinations = current_user.customer.destinations.reorder('geocoding_accuracy ASC NULLS LAST').includes([:tags, visits: :tags])
        @tags = current_user.customer.tags
        send_data render_to_string.encode(I18n.t('encoding'), invalid: :replace, undef: :replace, replace: ''),
            type: 'text/csv',
            filename: format_filename(t('activerecord.models.destinations.other')) + '.csv',
            disposition: params.key?(:disposition) ? params[:disposition] : 'attachment'
      end
      format.csv do
        @destinations = current_user.customer.destinations.reorder('geocoding_accuracy ASC NULLS LAST').includes([:tags, visits: :tags])
        @tags = current_user.customer.tags
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
    if turbo_frame_request? && turbo_frame_request_id == "form_sidebar"
      render "new_sidebar", layout: false
    end
  end

  def edit
    if turbo_frame_request? && turbo_frame_request_id == "form_sidebar"
      render "edit_sidebar", layout: false
    end
  end

  # V2 sidebar: persist a new visit server-side, then re-render the destination form in turbo-frame#form_sidebar.
  def append_visit
    unless turbo_frame_request? && turbo_frame_request_id == "form_sidebar"
      respond_to do |format|
        format.html { redirect_to edit_destination_path(@destination) }
      end
      return
    end

    respond_to do |format|
      format.html do
        visit = build_visit_to_append
        ActiveRecord::Base.transaction do
          visit.save!
          @destination.customer.save!
        end
        @destination.reload
        render "edit_sidebar", layout: false
      rescue ActiveRecord::RecordInvalid => e
        @destination.reload
        flash.now[:error] = e.record.errors.full_messages.to_sentence
        render "edit_sidebar", layout: false, status: :unprocessable_entity
      end
    end
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
        format.html do
          if turbo_frame_request? && turbo_frame_request_id == "form_sidebar"
            render "new_sidebar", layout: false, status: :unprocessable_entity
          else
            render action: "new"
          end
        end
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
          format.html do
            if turbo_frame_request? && turbo_frame_request_id == "form_sidebar"
              render "edit_sidebar", layout: false, status: :unprocessable_entity
            else
              render action: "edit"
            end
          end
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

    @import_csv = ImportCsv.new(
      column_def: @columns_default,
      vehicle_usage_set_id: default_import_vehicle_usage_set_id
    )
    @import_tomtom = ImportTomtom.new
  end

  def upload_csv
    respond_to do |format|
      @importer = ImporterDestinations.new(current_user.customer, import_planning_attributes_from_params)
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
      @import_csv = ImportCsv.new(vehicle_usage_set_id: default_import_vehicle_usage_set_id)
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

  def build_visit_to_append
    last = @destination.visits.reorder(id: :desc).first
    if last
      visit = last.dup
      visit.destination = @destination
      visit.ref = nil
      visit
    else
      @destination.visits.build(duration: @destination.customer.visit_duration)
    end
  end

  def assign_visit_custom_attributes
    customer = @destination&.customer || current_user&.customer
    @visit_custom_attributes = customer ? customer.custom_attributes.for_visit.to_a : []
  end

  def time_with_day_params(params, local_params, times)
    va = local_params[:visits_attributes]
    return if va.blank?

    raw_root = params[:destination]&.dig(:visits_attributes)
    return if raw_root.blank?

    if va.is_a?(Array)
      va.each_with_index do |_, i|
        times.each do |time|
          local_params[:visits_attributes][i][time] = ChronicDuration.parse("#{raw_root[i]["#{time}_day".to_sym]} days and #{local_params[:visits_attributes][i][time].tr(':', 'h')}min", keep_zero: true) unless raw_root[i]["#{time}_day".to_sym].to_s.empty? || local_params[:visits_attributes][i][time].to_s.empty?
        end
      end
    else
      # Strong params use ActionController::Parameters (not a Hash); keys are usually "1", "2", …
      va.each_pair do |k, _|
        raw = raw_root[k] || raw_root[k.to_s] || raw_root[k.to_i]
        next unless raw

        times.each do |time|
          day_key = "#{time}_day"
          day_part = raw[day_key] || raw[day_key.to_sym]
          next if day_part.to_s.empty? || local_params[:visits_attributes][k][time].to_s.empty?

          local_params[:visits_attributes][k][time] =
            ChronicDuration.parse("#{day_part} days and #{local_params[:visits_attributes][k][time].tr(':', 'h')}min", keep_zero: true)
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
    if params[:visits_attributes]
      params[:visits_attributes].each{ |p|
        if !p[:quantities] && p[:quantity] && !current_user.customer.deliverable_units.empty?
          p[:quantities] = { current_user.customer.deliverable_units[0].id => p.delete(:quantity) }
        end
      }
    end

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
        quantities_operations: current_user.customer.deliverable_units.map{ |du| du.id.to_s },
        deliveries: current_user.customer.deliverable_units.map{ |du| du.id.to_s },
        pickups: current_user.customer.deliverable_units.map{ |du| du.id.to_s }
      ]
    )
    if o[:visits_attributes]
      visits = o[:visits_attributes]
      visit_rows = visits.is_a?(Array) ? visits : visits.each_value
      visit_rows.each do |v|
        next unless v && v[:quantities_operations]

        v[:quantities_operations].each do |k, qo|
          v[:quantities][k] = "#{-v[:quantities][k].to_f}" if v[:quantities][k].to_f > 0 && qo.to_sym == :empty
        end
      end
    end
    o
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def import_csv_params
    params.require(:import_csv).permit(
      :replace,
      :file,
      :delete_plannings,
      :vehicle_usage_set_id,
      column_def: @importer.columns.keys
    )
  end

  def import_planning_attributes_from_params
    vehicle_usage_set_id = params.dig(:import_csv, :vehicle_usage_set_id).presence || default_import_vehicle_usage_set_id
    return {} if vehicle_usage_set_id.blank?

    {
      vehicle_usage_set: current_user.customer.vehicle_usage_sets.find(vehicle_usage_set_id)
    }
  end

  def default_import_vehicle_usage_set_id
    current_user.customer.vehicle_usage_sets.pick(:id)
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def import_tomtom_params
    params.require(:import_tomtom).permit(:replace)
  end
end
