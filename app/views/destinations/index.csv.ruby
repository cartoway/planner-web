CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  csv << csv_column_titles(@customer)
  @destinations.each { |destination|
    csv_columns_content(destination, @customer).each{ |row| csv << row }
  }
}
