class StopPhotosController < ApplicationController
  before_action :authenticate_driver!, only: [:create, :destroy]
  before_action :set_stop, only: [:create, :destroy]
  before_action :authorize_driver_stop!, only: [:create, :destroy]
  rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :not_found_error

  def create
    return render_proofs_disabled unless proofs_enabled?

    files = Array.wrap(params[:photos]).compact
    if @stop.attach_photos(files)
      render json: { photos: @stop.serialized_photos }, status: :created
    else
      render json: { error: @stop.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def destroy
    attachment = @stop.photos_attachments.find_by(id: params[:id]) ||
                 @stop.photos_attachments.find_by!(blob_id: params[:id])
    unless @stop.destroy_photo(attachment)
      render json: { error: I18n.t('stops.mobile.photos_delete_expired'), photos: @stop.serialized_photos }, status: :forbidden
      return
    end
    render json: { photos: @stop.serialized_photos }
  end

  def show
    blob = Stop.find_photo_blob!(params[:signed_id])
    raise ActiveRecord::RecordNotFound unless blob.attachments.exists?(record_type: %w[Stop OperationStop], name: 'photos')

    send_data blob.download,
              filename: blob.filename.to_s,
              type: blob.content_type,
              disposition: 'inline'
  end

  private

  def set_stop
    @stop = if params[:operation_stop_id]
              OperationStop.find(params[:operation_stop_id])
            else
              Stop.find(params[:stop_id])
            end
  end

  def authorize_driver_stop!
    vehicle_id = if @stop.is_a?(OperationStop)
                   @stop.operation_route.vehicle_id
                 else
                   @stop.route.vehicle_usage&.vehicle_id
                 end
    raise ActiveRecord::RecordNotFound unless vehicle_id == current_vehicle.id
  end

  def proofs_enabled?
    stop_customer.enable_proofs?
  end

  def stop_customer
    if @stop.is_a?(OperationStop)
      @stop.operation_route.operation.customer
    else
      @stop.route.planning.customer
    end
  end

  def render_proofs_disabled
    render json: { error: I18n.t('stops.mobile.proofs_disabled') }, status: :forbidden
  end
end
