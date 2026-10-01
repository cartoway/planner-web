# frozen_string_literal: true

class DeliveryTrackingsController < ApplicationController
  layout 'delivery_tracking'
  skip_before_action :api_key?, :driver_token?, :set_driver, :customer_payment_period

  def show
    @tracking = OperationDeliveryTracking.find_by!(token: params[:token])
    if @tracking.expired?
      render :expired, status: :gone
      return
    end

    @view = DeliveryTrackings::PublicStatus.new(@tracking)
    @current = @view.current_visit
    @terminal = @current&.terminal
  end
end
