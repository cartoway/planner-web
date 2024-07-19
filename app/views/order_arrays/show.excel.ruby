CSV.generate(**{col_sep: ';', row_sep: "\r\n"}) { |csv|
  render partial: 'show', formats: [:csv], locals: {csv: csv}
}
