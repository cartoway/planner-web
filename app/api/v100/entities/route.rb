class V100::Entities::Route < V100::Entities::RouteProperties
  include QuantitiesEntityHelper

  def self.entity_name
    'V100_Route'
  end

  expose(:ref, documentation: { type: String })
  expose(:vehicle_ref, documentation: { type: String, desc: 'Vehicle ref' }) { |m|
    m.vehicle_usage&.vehicle&.ref
  }
  expose(:distance, documentation: { type: Float, desc: 'Total route\'s distance.' })
  expose(:emission, documentation: { type: Float })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:start, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.start if m.start
  }
  expose(:end, documentation: { type: DateTime }) { |m|
    (m.planning.date || Time.zone.today).beginning_of_day + m.end if m.end
  }
  expose(:outdated, documentation: { type: 'Boolean' })

  expose(:departure_status, documentation: { type: String, desc: 'Departure status of start store.' }) { |route| route.departure_status && I18n.t('plannings.edit.stop_status.' + route.departure_status.downcase, default: route.departure_status) }
  expose(:departure_eta, documentation: { type: DateTime, desc: 'Estimated time of departure from remote device for start store.' })

  expose(:arrival_status, documentation: { type: String, desc: 'Arrival status of stop store.' }) { |route| route.arrival_status && I18n.t('plannings.edit.stop_status.' + route.arrival_status.downcase, default: route.arrival_status) }
  expose(:arrival_eta, documentation: { type: DateTime, desc: 'Estimated time of arrival from remote device for stop store.' })

  expose(:stops, using: V100::Entities::Stop, documentation: { type: V100::Entities::Stop, is_array: true })
  expose(:stop_out_of_drive_time, documentation: { type: 'Boolean' })
  expose(:stop_out_of_work_time, documentation: { type: 'Boolean' })
  expose(:stop_out_of_max_distance, documentation: { type: 'Boolean' })
  expose(:stop_distance, documentation: { type: Float, desc: 'Distance between the vehicle\'s store_stop and last stop.' })
  expose(:stop_drive_time, documentation: { type: Integer, desc: 'Time in seconds between the vehicle\'s store_stop and last stop.' })
  expose(:updated_at, documentation: { type: DateTime, desc: 'Last Updated At.'})
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent.'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device.'})
  expose(:optimized_at, documentation: { type: DateTime, desc: 'Last optimized at.'})
  expose(:out_of_max_ride_distance, documentation: { type: 'Boolean' })
  expose(:out_of_max_ride_duration, documentation: { type: 'Boolean' })
  expose(:quantities, using: V100::Entities::DeliverableUnitQuantity, documentation: { type: V100::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }
  expose(:geojson, documentation: { type: String, desc: 'Geojson string of track and stops of the route. Default empty, set parameter geojson=true|point|polyline to get this extra content.' }) { |m, options|
    if options[:geojson] && options[:geojson] != :false
      m.to_geojson(true, true,
        if options[:geojson] == :polyline
          :polyline
        elsif options[:geojson] == :point
          false
        else
          true
        end)
    end
  }
end

class V100::Entities::RouteWithVehicleDetails < V100::Entities::Route
  expose(:vehicle_usage, using: V100::Entities::VehicleUsageWithVehicle, documentation: { type: V100::Entities::VehicleUsageWithVehicle })

  def self.entity_name
    'V100_RouteWithVehicleDetails'
  end
end

class V100::Entities::RouteStatus < Grape::Entity
  def self.entity_name
    'V100_RouteStatus'
  end

  expose(:id, documentation: { type: Integer })
  expose(:vehicle_usage_id, documentation: { type: Integer })
  expose(:last_sent_to, documentation: { type: String, desc: 'Type GPS Device of Last Sent.'})
  expose(:last_sent_at, documentation: { type: DateTime, desc: 'Last Time Sent To External GPS Device.'})
  expose(:quantities, using: V100::Entities::DeliverableUnitQuantity, documentation: { type: V100::Entities::DeliverableUnitQuantity, is_array: true, param_type: 'form' }) { |m|
    convert_pickups_deliveries_to_quantities(m.pickups, m.deliveries)
  }
  expose(:stops, using: V100::Entities::StopStatus, documentation: { type: V100::Entities::StopStatus, is_array: true })
end
