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
  include PlanningToolbarPermissions

  before_action :authenticate_user!, except: [:edit, :update]
  before_action :set_route_context, only: [:create_store_reload, :create_regulatory_rest, :destroy]
  before_action :authenticate_driver!, only: [:edit, :update]
  before_action :set_stop, only: [:show, :edit, :update, :delivery_note] # Before load_and_authorize_resource

  load_and_authorize_resource # Load resource except for show action

  # Cap print embeds: display is ~220px, keep ~4x for sharpness without shipping phone-res originals.
  PRINT_IMAGE_MAX_EDGE = 880
  PRINT_IMAGE_JPEG_QUALITY = 70

  def create_store_reload
    if @route && params[:store_reload_id]
      @store_reload = current_user.customer.store_reloads.find(params[:store_reload_id])
      respond_to do |format|
        if @route.add_store_reload(@store_reload) && @route.save && load_planning_with_scope && @planning.compute_saved && load_planning_with_scope
          @planning.capture_state!(trigger: 'update_stop')
          format.json { render json: { status: :ok } }
        else
          errors = (@route.errors&.full_messages || []) + (@planning&.errors&.full_messages || [])
          format.json { render json: { status: :unprocessable_entity, error: errors }, status: :unprocessable_entity }
        end
      end
    end
  end

  def create_regulatory_rest
    unless @route&.vehicle_usage&.regulatory_rest?
      respond_to do |format|
        format.json {
          render json: {
            status: :unprocessable_entity,
            error: I18n.t('plannings.edit.create_regulatory_rest.error.not_enabled')
          }, status: :unprocessable_entity
        }
      end
      return
    end

    respond_to do |format|
      if @route.add_rest && @route.save && load_planning_with_scope && @planning.compute_saved && load_planning_with_scope
        @planning.capture_state!(trigger: 'update_stop')
        format.json { render json: { status: :ok } }
      else
        errors = (@route.errors&.full_messages || []) + (@planning&.errors&.full_messages || [])
        format.json { render json: { status: :unprocessable_entity, error: errors }, status: :unprocessable_entity }
      end
    end
  end

  def destroy
    if @route && params[:stop_id]
      stop = @route.stops.find(params[:stop_id])
      respond_to do |format|
        if stop.is_a?(StopStore)
          @route.remove_store_reload(stop) && @route.save!
        elsif stop.is_a?(StopRest) && @route.vehicle_usage&.regulatory_rest?
          @route.remove_rest(stop) && @route.save!
        else
          format.js {
            head :no_content
          }
          return
        end
        if load_planning_with_scope && @planning.compute_saved && load_planning_with_scope
          @planning.capture_state!(trigger: 'update_stop')
          planning_data = JSON.parse(render_to_string(template: 'plannings/show.json.jbuilder'), symbolize_names: true)
          route_data = planning_data[:routes].select{ |route| route[:route_id] == @route.id }
          format.js { render partial: 'routes/update.js.erb', locals: { updated_routes: route_data, summary: planning_summary(@planning) } }
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

  def delivery_note
    raise ActiveRecord::RecordNotFound unless @stop.delivery_note_available?

    @visit = @stop.visit
    @destination = @visit.destination
    @route = @stop.route
    @planning = @route.planning
    @customer = @planning.customer
    # Embed media as data URIs so Firefox print preview does not wait on network/JS.
    @photos = @stop.photos.map { |photo| print_embedded_image(photo) }
    @signature = @stop.signature.attached? ? print_embedded_image(@stop.signature) : nil
    respond_to do |format|
      format.html { render layout: 'print' }
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
    raise ActiveRecord::RecordNotFound if @stop.nil?

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

  def set_route_context
    @manage_planning =
      if request.referer&.match('api-web')
        ApiWeb::V01::PlanningsController.manage
      else
        PlanningsController.manage
      end
    @route = current_user.customer.plannings.find(params[:planning_id])
                         .routes.includes_destinations_and_stores.where(id: params[:route_id]).first!
    @planning = @route.planning
    apply_planning_toolbar_operation_flags!
    @available_store_reloads =
      current_user.customer.stores.flat_map { |store|
        store.store_reloads.map.with_index { |store_reload, index|
          {
            id: store_reload.id,
            name: store_reload.name,
            ref: store_reload.ref,
            icon: store_reload.icon,
            color: store_reload.color,
            index: index + 1
          }
        }
      }.compact
    @with_stops = ValueToBoolean.value_to_boolean(params[:with_stops], true)
    @colors = COLORS_TABLE.dup.unshift(nil)
  end

  def load_planning_with_scope
    @planning = current_user.customer.plannings.where(id: params[:planning_id]).preload_route_details.first!
  end

  def print_embedded_image(attachment)
    bytes, content_type = print_image_bytes(attachment)
    {
      filename: attachment.blob.filename.to_s,
      url: "data:#{content_type};base64,#{Base64.strict_encode64(bytes)}"
    }
  end

  def print_image_bytes(attachment)
    blob = attachment.blob
    return [blob.download, blob.content_type] unless attachment.variable?

    processed = attachment.variant(
      resize_to_limit: [PRINT_IMAGE_MAX_EDGE, PRINT_IMAGE_MAX_EDGE],
      format: :jpeg,
      saver: { quality: PRINT_IMAGE_JPEG_QUALITY, strip: true }
    ).processed
    [processed.download, 'image/jpeg']
  rescue StandardError => e
    Rails.logger.warn("delivery_note image resize failed (#{e.class}): #{e.message}")
    [blob.download, blob.content_type]
  end
end
