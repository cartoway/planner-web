CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  csv << csv_column_titles(@customer, { extra_destination_columns: [:zone] })
  @zoned_destinations.each{ |destination, zone_names|
    csv_columns_content(destination, @customer, { extra_destination_columns: [zone_names] }).each { |row|
      csv << row
    }
  }
}
