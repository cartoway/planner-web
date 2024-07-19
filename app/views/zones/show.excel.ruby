CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  csv << csv_column_titles(@customer, { extra_destination_columns: [:zone] })
  @zones_destinations.each { |destination, zone_name|
    csv_columns_content(destination, @customer, { extra_destination_columns: [zone_name] }).each{ |row|
      csv << row
    }
  }
}
