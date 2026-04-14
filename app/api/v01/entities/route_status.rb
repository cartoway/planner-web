class V01::Entities::RouteStatus < Grape::Entity
  include QuantitiesEntityHelper

  def self.entity_name
    'V01_RouteStatus'
  end

  expose(:id, documentation: { type: Integer })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent.'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device.'})
  expose(:quantities, using: V01::Entities::DeliverableUnitQuantity, documentation: { type: V01::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }

  expose(:departure_status, documentation: { type: String, desc: 'Departure status of start store.' }) { |route| route.start_route_data&.status && I18n.t('plannings.edit.stop_status.' + route.start_route_data.status.downcase, default: route.start_route_data.status) }
  expose(:departure_status_code, documentation: { type: String, desc: 'Status code of start store.' }) { |route| route.start_route_data&.status&.downcase }
  expose(:departure_eta, documentation: { type: DateTime, desc: 'Estimated time of departure from remote device.' }) { |route| route.start_route_data&.eta }
  expose(:departure_eta_formated, documentation: { type: DateTime, desc: 'Estimated time of departure from remote device.' }) { |route| route.start_route_data&.eta && I18n.l(route.start_route_data.eta, format: :hour_minute) }

  expose(:arrival_status, documentation: { type: String, desc: 'Arrival status of stop store.' }) { |route| route.stop_route_data&.status && I18n.t('plannings.edit.stop_status.' + route.stop_route_data.status.downcase, default: route.stop_route_data.status) }
  expose(:arrival_status_code, documentation: { type: String, desc: 'Status code of stop store.' }) { |route| route.stop_route_data&.status&.downcase }
  expose(:arrival_eta, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device.' }) { |route| route.stop_route_data&.eta }
  expose(:arrival_eta_formated, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device.' }) { |route| route.arrival_eta && I18n.l(route.arrival_eta, format: :hour_minute) }

  expose(:size_active, documentation: { type: Integer, desc: 'Main route_data: active stops count.' })
  expose(:size_destinations, documentation: { type: Integer })
  expose(:size_store_reloads, documentation: { type: Integer })
  expose(:stops_size, documentation: { type: Integer })
  expose(:no_geolocalization, documentation: { type: 'Boolean' })
  expose(:no_path, documentation: { type: 'Boolean' })
  expose(:unmanageable_capacity, documentation: { type: 'Boolean' })
  expose(:out_of_capacity, documentation: { type: 'Boolean' })
  expose(:out_of_drive_time, documentation: { type: 'Boolean' })
  expose(:out_of_force_position, documentation: { type: 'Boolean' })
  expose(:out_of_work_time, documentation: { type: 'Boolean' })
  expose(:out_of_window, documentation: { type: 'Boolean' })
  expose(:out_of_max_distance, documentation: { type: 'Boolean' })
  expose(:out_of_max_reload, documentation: { type: 'Boolean' })
  expose(:out_of_max_ride_distance, documentation: { type: 'Boolean' })
  expose(:out_of_max_ride_duration, documentation: { type: 'Boolean' })
  expose(:out_of_relation, documentation: { type: 'Boolean' })
  expose(:out_of_skill, documentation: { type: 'Boolean' })
  expose(:max_loads, documentation: { type: Hash, desc: 'Main route_data max loads (jsonb).' })

  expose(:stops, using: V01::Entities::StopStatus, documentation: { type: V01::Entities::StopStatus, is_array: true })
end
