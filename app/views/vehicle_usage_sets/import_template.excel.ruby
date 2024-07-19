require 'importer_vehicle_usage_sets'

CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  columns = ImporterVehicleUsageSets.new(current_user.customer).columns.values.select{ |data| data[:title] && data[:required] != I18n.t('destinations.import_file.format.deprecated') }
  csv << columns.collect{ |data| data[:title] }
  csv << columns.collect{ |data|
    data[:format] + (!data[:required] || data[:required] != I18n.t('vehicle_usage_sets.import.format.required') ?
    ' (' + (data[:required] ? data[:required] : I18n.t('vehicle_usage_sets.import.format.optional')) + ')' :
    '')
  }
}
