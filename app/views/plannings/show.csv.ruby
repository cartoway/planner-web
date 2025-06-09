CSV.generate { |csv|
  csv << export_column_titles(@customer, @columns, @custom_columns)
  render partial: "routes/index.csv", formats: [:csv], locals: { planning: @planning, csv: csv, summary: @is_summary }
}
