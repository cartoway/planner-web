CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  csv << export_column_titles(@customer, @columns, @custom_columns)
  @plannings.each do |planning|
    render partial: 'routes/index.excel', locals: {planning: planning, csv: csv, summary: @is_summary}
  end
}
