CSV.generate({col_sep: ';', row_sep: "\r\n"}) { |csv|
  csv << [
    I18n.t('destinations.import_file.ref'),
    I18n.t('destinations.import_file.name'),
    I18n.t('destinations.import_file.street'),
    I18n.t('destinations.import_file.detail'),
    I18n.t('destinations.import_file.postalcode'),
    I18n.t('destinations.import_file.city')
  ] + (@customer.with_state? ? [I18n.t('destinations.import_file.state')] : []) + [
    I18n.t('destinations.import_file.country'),
    I18n.t('destinations.import_file.lat'),
    I18n.t('destinations.import_file.lng'),
    I18n.t('destinations.import_file.geocoding_accuracy'),
    I18n.t('destinations.import_file.geocoding_level'),
    I18n.t('destinations.import_file.comment'),
    I18n.t('destinations.import_file.phone_number'),
    I18n.t('destinations.import_file.tags'),
    I18n.t('destinations.import_file.without_visit'),
    I18n.t('destinations.import_file.ref_visit'),
    I18n.t('destinations.import_file.duration'),
    I18n.t('destinations.import_file.time_window_start_1'),
    I18n.t('destinations.import_file.time_window_end_1'),
    I18n.t('destinations.import_file.time_window_start_2'),
    I18n.t('destinations.import_file.time_window_end_2'),
    I18n.t('destinations.import_file.priority'),
    I18n.t('destinations.import_file.tags_visit')
  ] + (@customer.enable_orders ?
    [] :
    @customer.deliverable_units.map{ |du|
      I18n.t('destinations.import_file.quantity') + (du.label ? '[' + du.label + ']' : '')
    })
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
          @customer.deliverable_units.map{ |du|
            visit.quantities[du.id]
          })
      }
    else
      csv << destination_columns + ['x']
    end
  }
}
