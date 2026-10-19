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

  def destination_tracking_email(tracking)
    stop = tracking.visit_stops.first
    snap = stop&.destination_snapshot || {}
    snap['email'].presence || tracking.destination&.email
  end

  def destination_tracking_phone(tracking)
    stop = tracking.visit_stops.first
    snap = stop&.destination_snapshot || {}
    snap['phone_number'].presence || tracking.destination&.phone_number
  end

  # Count rows with a filled contact for the selected send channel (email|sms|none).
  def contact_rows_filled_count(rows, channel)
    channel = channel.to_s
    return 0 if channel == 'none'

    key = channel == 'sms' ? :phone : :email
    Array(rows).count { |row| row[key].to_s.strip.present? }
  end

  # Green if complete, yellow if >75%, red otherwise.
  def contact_rows_count_badge_class(filled, total)
    return 'text-bg-success' if total.to_i.zero? || filled.to_i >= total.to_i
    return 'text-bg-warning' if filled.to_f / total > 0.75

    'text-bg-danger'
  end

  # Prefer a channel that has a contact when several are enabled.
  def default_contact_channel(email, phone, channels)
    channels = Array(channels).map(&:to_sym)
    return 'none' if channels.empty?
    return 'email' if channels.include?(:email) && email.present?
    return 'sms' if channels.include?(:sms) && phone.present?
    return 'email' if channels.include?(:email)
    return 'sms' if channels.include?(:sms)

    'none'
  end

  def operation_driver_contact_rows(routes)
    Array(routes).map do |route|
      email = route.driver_email
      phone = route.driver_phone
      {
        id: route.id,
        label: route.ref.presence || route.vehicle_name,
        sublabel: t('operations.show.last_sent', at: (route.last_sent_at ? l(route.last_sent_at, format: :short) : '—')),
        email: email,
        phone: phone
      }
    end
  end

  def operation_destination_contact_rows(trackings)
    operation_destination_contact_groups(trackings).flat_map { |group| group[:rows] }
  end

  # Group destination trackings by their primary operation route (first visit stop).
  def operation_destination_contact_groups(trackings)
    trackings = Array(trackings)
    OperationDeliveryTracking.preload_visit_stops!(trackings)
    buckets = Hash.new { |hash, key| hash[key] = { route: nil, rows: [] } }

    trackings.each do |tracking|
      stop = tracking.visit_stops.first
      route = stop&.operation_route
      key = route&.id || :unassigned
      buckets[key][:route] ||= route
      buckets[key][:rows] << {
        id: tracking.id,
        label: tracking.destination&.name.presence || tracking.destination_id,
        sublabel: tracking.destination&.street,
        email: destination_tracking_email(tracking),
        phone: destination_tracking_phone(tracking)
      }
    end

    buckets.values.sort_by { |group| group[:route]&.index.to_i }.map do |group|
      route = group[:route]
      label = if route
                route.ref.presence || route.vehicle_name || t('operations.show.unassigned')
              else
                t('operations.show.unassigned')
              end
      { label: label, rows: group[:rows] }
    end
  end

  def planning_driver_contact_rows(routes, selected_ids: nil)
    selected = selected_ids&.map(&:to_i)
    Array(routes).filter_map do |route|
      vehicle = route.vehicle_usage&.vehicle
      next unless vehicle

      label = [route.ref, vehicle.name].compact.join(' ').presence || "##{route.id}"
      {
        id: route.id,
        route_id: route.id,
        label: label,
        email: vehicle.contact_email,
        phone: vehicle.phone_number,
        visible: selected ? selected.include?(route.id) : true
      }
    end
  end

  def driver_contact_channels(customer)
    [].tap do |channels|
      channels << :email if customer.enable_email_driver
      channels << :sms if customer.enable_sms_driver
    end
  end

  def destination_contact_channels(customer)
    [].tap do |channels|
      channels << :email if customer.enable_email_destination
      channels << :sms if customer.enable_sms_destination
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
