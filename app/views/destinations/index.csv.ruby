CSV.generate { |csv|
  csv << csv_column_titles(@customer)
  @destinations.each { |destination|
    destination_columns = [
      destination.ref,
      destination.name,
      destination.street,
      destination.detail,
      destination.postalcode,
      destination.city,
    ] + (@customer.with_state? ? [destination.state] : []) + [
      destination.country,
      destination.lat,
      destination.lng,
      destination.geocoding_accuracy,
      destination.geocoding_level,
      destination.comment,
      destination.phone_number,
      destination.tags.collect(&:label).join(',')
    ]
    if destination.visits.size > 0
      destination.visits.each { |visit|
        csv << destination_columns + [
          '',
          visit.ref,
          visit.duration_absolute_time_with_seconds,
          visit.time_window_start_1_absolute_time,
          visit.time_window_end_1_absolute_time,
          visit.time_window_start_2_absolute_time,
          visit.time_window_end_2_absolute_time,
          visit.priority,
          visit.tags.collect(&:label).join(',')
        ] + (@customer.enable_orders ?
          [] :
          @customer.deliverable_units.flat_map{ |du|
            [visit.quantities[du.id],
            visit.quantities_operations[du.id] && I18n.t("destinations.import_file.quantity_operation_#{visit.quantities_operations[du.id]}")]
          })
      }
    else
      csv << destination_columns + ['x']
    end
  }
}
