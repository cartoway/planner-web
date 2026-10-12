class StopSignaturesController < ApplicationController
  before_action :authenticate_driver!, only: [:create]
  before_action :set_operation_stop, only: [:create]
  before_action :authorize_driver_stop!, only: [:create]
  rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :not_found_error

  def create
    return render_proofs_disabled unless proofs_enabled?

    if @operation_stop.attach_signature(params[:signature])
      render json: { signature: @operation_stop.serialized_signature }, status: :created
    else
      render json: { error: @operation_stop.errors.full_messages.to_sentence }, status: :unprocessable_entity
    end
  end

  def show
    blob = OperationStop.find_signature_blob!(params[:signed_id])
    raise ActiveRecord::RecordNotFound unless blob.attachments.exists?(record_type: 'OperationStop', name: 'signature')

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
