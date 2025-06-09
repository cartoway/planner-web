CSV.generate { |csv|
  csv << export_column_titles(@customer, @columns, @custom_columns)
  @plannings.each do |planning|
    render partial: "routes/index.csv", locals: { planning: planning, csv: csv, summary: @is_summary }
  end
}
