CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  csv << [
    I18n.t('vehicles.import.ref_vehicle'),
    I18n.t('vehicles.import.name_vehicle'),
    I18n.t('vehicles.import.contact_email'),
    I18n.t('vehicles.import.phone_number'),
    I18n.t('vehicles.import.emission'),
    I18n.t('vehicles.import.consumption'),
    I18n.t('vehicles.import.max_distance'),
    I18n.t('vehicles.import.max_ride_distance'),
    I18n.t('vehicles.import.max_ride_duration')
  ] +
    @vehicle_usage_set.customer.deliverable_units.map { |du|
      I18n.t('vehicles.import.capacities') + (du.label ? "[#{du.label}]" : "#{du.id}")
    } +
    @vehicle_usage_set.customer.custom_attributes.select(&:vehicle?).map { |ca|
      I18n.t('vehicles.import.custom_attributes') + '[' + ca.name + ']'
    } +
  [
    I18n.t('vehicles.import.router_mode'),
    I18n.t('vehicles.import.router_dimension'),
    I18n.t('vehicles.import.router_options'),
    I18n.t('vehicles.import.speed_multiplier'),
    I18n.t('vehicles.import.color'),
    I18n.t('vehicles.import.tags'),
    I18n.t('vehicles.import.devices'),

    I18n.t('vehicle_usage_sets.import.cost_distance'),
    I18n.t('vehicle_usage_sets.import.cost_fixed'),
    I18n.t('vehicle_usage_sets.import.cost_time'),
    I18n.t('vehicle_usage_sets.import.time_window_start'),
    I18n.t('vehicle_usage_sets.import.time_window_end'),
    I18n.t('vehicle_usage_sets.import.store_start_ref'),
    I18n.t('vehicle_usage_sets.import.store_stop_ref'),
    I18n.t('vehicle_usage_sets.import.rest_start'),
    I18n.t('vehicle_usage_sets.import.rest_stop'),
    I18n.t('vehicle_usage_sets.import.rest_duration'),
    I18n.t('vehicle_usage_sets.import.store_rest_ref'),
    I18n.t('vehicle_usage_sets.import.service_time_start'),
    I18n.t('vehicle_usage_sets.import.service_time_end'),
    I18n.t('vehicle_usage_sets.import.work_time'),
    I18n.t('vehicle_usage_sets.import.tags')
  ]

  device_keys = {}
  Planner::Application.config.devices.to_h.each { |device_name, device_object|
      if device_object.respond_to?('definition')
        device_definition = device_object.definition
        if device_definition.key?(:forms) && device_definition[:forms].key?(:vehicle)
          device_keys[device_name] = device_definition[:forms][:vehicle].keys
        end
      end
  }

  @vehicle_usage_set.vehicle_usages.each { |vehicle_usage|
    vehicle_columns = [
      vehicle_usage.vehicle.ref,
      vehicle_usage.vehicle.name,
      vehicle_usage.vehicle.contact_email,
      vehicle_usage.vehicle.phone_number,
      vehicle_usage.vehicle.emission,
      vehicle_usage.vehicle.consumption,
      vehicle_usage.vehicle.max_distance || @vehicle_usage_set.max_distance,
      vehicle_usage.vehicle.max_ride_distance || @vehicle_usage_set.max_ride_distance,
      vehicle_usage.vehicle.max_ride_duration || @vehicle_usage_set.max_ride_duration
    ] +
    @vehicle_usage_set.customer.deliverable_units.map { |du|
      vehicle_usage.vehicle.capacities[du.id]
    } +
    @vehicle_usage_set.customer.custom_attributes.select(&:vehicle?).map{ |ca|
      vehicle_usage.vehicle.custom_attributes_typed_hash[ca.name]
    } +
    [
      vehicle_usage.vehicle.router.try(:mode),
      vehicle_usage.vehicle.router_dimension,
      vehicle_usage.vehicle.router_options.to_json,
      vehicle_usage.vehicle.speed_multiplier,
      vehicle_usage.vehicle.color,
      vehicle_usage.vehicle.tags.collect(&:label).join(',')
    ]

    enabled_devices = {}
    @vehicle_usage_set.customer.device.enableds.keys.each { |device_key|
      enabled_devices.merge!(vehicle_usage.vehicle.devices.slice(*device_keys[device_key]))
    }
    vehicle_columns << enabled_devices.select { |key, value| !value.to_s.empty? }.to_json

    vehicle_usage_columns = [
      vehicle_usage.default_cost_distance,
      vehicle_usage.default_cost_fixed,
      vehicle_usage.default_cost_time,
      vehicle_usage.default_time_window_start_absolute_time,
      vehicle_usage.default_time_window_end_absolute_time,
      vehicle_usage.default_store_start.try(:ref),
      vehicle_usage.default_store_stop.try(:ref),
      vehicle_usage.default_rest_start_absolute_time,
      vehicle_usage.default_rest_stop_absolute_time,
      vehicle_usage.default_rest_duration_time,
      vehicle_usage.default_store_rest.try(:ref),
      vehicle_usage.default_service_time_start,
      vehicle_usage.default_service_time_end,
      vehicle_usage.default_work_time,
      vehicle_usage.tags.collect(&:label).join(',')
    ]

    csv << vehicle_columns + vehicle_usage_columns
  }
}
