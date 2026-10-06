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

  def operation_live_i18n
    {
      stops: t('operations.show.stops'),
      en_route: t('operations.show.en_route'),
      # JS replaces %{count} literally (operation_show_controller).
      late: t('operations.show.late', count: '%{count}'), # rubocop:disable Style/FormatStringToken
      late_risk: t('operations.show.late_risk'),
      exception: t('plannings.edit.stop_status.exception'),
      stop_status: I18n.t('plannings.edit.stop_status'),
      stop_rest_status: I18n.t('plannings.edit.stop_rest_status'),
      stop_store_status: I18n.t('plannings.edit.stop_store_status')
    }
  end
end
