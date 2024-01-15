CSV.generate { |csv|
  csv << export_column_titles(@columns, @custom_columns)
  @plannings.each do |planning|
    render partial: "routes/index.csv", formats: [:ruby], locals: { planning: planning, csv: csv }
  end
}
