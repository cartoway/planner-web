class StopPhotosController < ApplicationController
  before_action :authenticate_driver!, only: [:create, :destroy]
  before_action :set_operation_stop, only: [:create, :destroy]
  before_action :authorize_driver_stop!, only: [:create, :destroy]
  rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :not_found_error

  def create
    return render_proofs_disabled unless proofs_enabled?

    files = Array.wrap(params[:photos]).compact
    if @operation_stop.attach_photos(files)
      render json: { photos: @operation_stop.serialized_photos }, status: :created
    else
      messages = @operation_stop.errors.full_messages
      render json: { error: messages.to_sentence, errors: messages }, status: :unprocessable_entity
    end
  end

  def destroy
    attachment = @operation_stop.photos_attachments.find_by(id: params[:id]) ||
                 @operation_stop.photos_attachments.find_by!(blob_id: params[:id])
    unless @operation_stop.destroy_photo(attachment)
      render json: { error: I18n.t('stops.mobile.photos_delete_expired'), photos: @operation_stop.serialized_photos }, status: :forbidden
      return
    end
    render json: { photos: @operation_stop.serialized_photos }
  end

  def show
    blob = OperationStop.find_photo_blob!(params[:signed_id])
    raise ActiveRecord::RecordNotFound unless blob.attachments.exists?(record_type: 'OperationStop', name: 'photos')

    send_data blob.download,
              filename: blob.filename.to_s,
              type: blob.content_type,
              disposition: 'inline'
  end

  private

  def set_operation_stop
    @operation_stop = OperationStop.find(params[:operation_stop_id])
  end

  def authorize_driver_stop!
    raise ActiveRecord::RecordNotFound unless @operation_stop.operation_route.vehicle_id == current_vehicle.id
  end

  def proofs_enabled?
    @operation_stop.operation_route.operation.customer.enable_proofs?
  end

  def render_proofs_disabled
    render json: { error: I18n.t('stops.mobile.proofs_disabled') }, status: :forbidden
  end
end
