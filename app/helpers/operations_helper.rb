# frozen_string_literal: true

module OperationsHelper
  def destination_tracking_contact(tracking, channel)
    stop = tracking.visit_stops.first
    snap = stop&.destination_snapshot || {}
    if channel == 'sms'
      snap['phone_number'].presence || tracking.destination&.phone_number
    else
      snap['email'].presence || tracking.destination&.email
    end
  end
end
