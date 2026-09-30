class StopSignaturesController < ApplicationController
  before_action :authenticate_driver!, only: [:create]
  before_action :set_stop, only: [:create]
  before_action :authorize_driver_stop!, only: [:create]
  rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :not_found_error

  def create
    if @stop.attach_signature(params[:signature])
      render json: { signature: @stop.serialized_signature }, status: :created
    else
      render json: { error: @stop.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def show
    blob = Stop.find_signature_blob!(params[:signed_id])
    raise ActiveRecord::RecordNotFound unless blob.attachments.exists?(record_type: %w[Stop OperationStop], name: 'signature')

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
end
