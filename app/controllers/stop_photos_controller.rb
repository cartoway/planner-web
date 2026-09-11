class StopPhotosController < ApplicationController
  before_action :authenticate_driver!, only: [:create, :destroy]
  before_action :set_stop, only: [:create, :destroy]
  before_action :authorize_driver_stop!, only: [:create, :destroy]
  rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :not_found_error

  def create
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
    raise ActiveRecord::RecordNotFound unless blob.attachments.exists?(record_type: 'Stop', name: 'photos')

    send_data blob.download,
              filename: blob.filename.to_s,
              type: blob.content_type,
              disposition: 'inline'
  end

  private

  def set_stop
    @stop = Stop.find(params[:stop_id])
  end

  def authorize_driver_stop!
    raise ActiveRecord::RecordNotFound unless @stop.route.vehicle_usage&.vehicle_id == current_vehicle.id
  end
end
