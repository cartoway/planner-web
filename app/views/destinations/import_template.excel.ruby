require 'importer_destinations'
CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  columns = ImporterDestinations.new(current_user.customer).columns
  custom_columns = current_user.customer.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef') || {}
  filtered = columns.select{ |_key, data| data[:title] && data[:required] != I18n.t('destinations.import_file.format.deprecated') }
  csv << filtered.collect{ |key, data| custom_columns[key.to_s].presence || data[:title] }
  csv << filtered.collect{ |_key, data|
    data[:format].to_s + (!data[:required] || data[:required] != I18n.t('destinations.import_file.format.required') ?
    ' (' + (data[:required] ? data[:required] : I18n.t('destinations.import_file.format.optional')) + ')' :
    '')
  }
}
