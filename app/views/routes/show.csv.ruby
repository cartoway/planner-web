CSV.generate { |csv|
  csv << export_column_titles(@customer, @columns, @custom_columns)
  render 'show', route: @route, csv: csv
}
