# Copyright © Mapotempo, 2013-2015
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
require 'value_to_boolean'

class ImportCsv
  include ActiveModel::Model
  include ActiveRecord::AttributeAssignment
  extend ActiveModel::Translation

  attr_accessor :importer, :replace, :file, :delete_plannings, :column_def, :content_code, :replace_vehicles
  validates :file, presence: true
  validate :data

  def replace=(value)
    @replace = ValueToBoolean.value_to_boolean(value)
  end

  def delete_plannings=(value)
    @delete_plannings = ValueToBoolean.value_to_boolean(value)
  end

  def replace_vehicles=(value)
    @replace_vehicles = ValueToBoolean.value_to_boolean(value)
  end

  def column_def=(values)
    @column_def = values&.symbolize_keys || {}
  end

  def name
    ((!file.original_filename.try(&:empty?) && file.original_filename) || (!file.filename.try(&:empty?) && file.filename)).try{ |s|
      s.split('.')[0..-2].join('.') if s.include?('.')
    }
  end

  def import(synchronous = false)
    if data
      begin
        last_row = last_line = nil
        Customer.transaction do
          importer_columns = @importer.columns
          allow_duplicated_ref = @importer.is_a?(ImporterDestinations)
          rows = @importer.import(data, name, synchronous, allow_duplicate: allow_duplicated_ref, ignore_errors: false, replace: replace, delete_plannings: delete_plannings, replace_vehicles: replace_vehicles, line_shift: (without_header? ? 0 : 1), column_def: column_def) { |row, line|
            if row
              # Column Names: Strip Whitespaces
              row = row.each_with_object({}){ |(k, v), hash| hash[k.is_a?(String) ? k.strip : k] = v } if row.is_a? Hash

              # Switch from locale or custom to internal column name
              r, row = row, {}
              importer_columns.each{ |key, v|
                next unless v[:title]

                if r.is_a?(Array)
                  # Import without column name or by merging columns
                  values = (column_def[key] && !column_def[key].empty? ? column_def[key] : (without_header? ? '' : v[:title])).split(',').map{ |c|
                    c.strip!
                    if c.to_i != 0
                      r[c.to_i - 1].is_a?(Array) ? r[c.to_i - 1][1] : r[c.to_i - 1]
                    else
                      r.find{ |rr| rr[0] == c }.try{ |rr| rr[1] }
                    end
                  }.compact
                  # lat or lng must be set even if empty but only when specified in columns
                  row[key] = values.join(' ') if should_fill_row?(key, r, values)
                elsif r.key?(v[:title])
                  # Import with column name
                  row[key] = r[v[:title]]
                end
              }
            end
            last_row = row
            last_line = line

            row
          }
          last_row = last_line = nil
          rows
        end
      rescue StandardError => e
        raise e if Rails.env.test? && !e.is_a?(ImportBaseError) && !e.is_a?(ImportBulkError) && !e.is_a?(Exceptions::OverMaxLimitError)

        message = e.is_a?(ImportInvalidRow) ? I18n.t('import.data_erroneous.csv', s: last_line) + ', ' : last_line && !e.is_a?(ImportBaseError) ? I18n.t('import.csv.line', s: last_line) + ', ' : ''
        message += e.message
        message[0] = message[0].capitalize
        message += (message.end_with?('.') ? ' ' : '. ') + I18n.t('destinations.import_file.check_custom_columns') if column_def && !column_def.values.compact.empty?
        # format error to be human friendly with row content (take into account customized column names)
        errors[:base] << error_and_format_row(message, last_row)
        Rails.logger.warn e.message
        Rails.logger.warn e.backtrace.join("\n")
        return false
      end
    end
  end

  def include?(column_name)
    test = data.collect do |line|
      if line.is_a? Array
        line.collect { |column|
          column.first == column_def[column_name]
        }
      else
        line.keys.include?(@importer.columns[column_name][:title])
      end
    end
    test.flatten.uniq.include?(true)
  end

  private

  def should_fill_row?(key, row, values)
    # lat or lng must be set even if empty but only when specified in columns
    values.present? ||
      (
        %I[lat lng].include?(key) &&
        (
          !without_header? &&
          row.to_h.key?(column_def[:lat].present? ? column_def[:lat] : 'lat') &&
          row.to_h.key?(column_def[:lng].present? ? column_def[:lng] : 'lng')
        )
      )
  end

  def data
    @data ||= parse_csv
  end

  def without_header?
    column_def && !column_def.values.join('').empty? && column_def.values.all?{ |v| v.strip.empty? || v.split(',').all?{ |vv| vv.to_i != 0 } }
  end

  def parse_csv
    return false unless file

    contents = File.open(file.tempfile, 'r:bom|utf-8').read
    unless contents.valid_encoding?
      detection = CharlockHolmes::EncodingDetector.detect(contents)
      if !contents || !detection[:encoding]
        errors[:file] << I18n.t('destinations.import_file.not_csv')
        return false
      end
      contents = CharlockHolmes::Converter.convert(contents, detection[:encoding], 'UTF-8')
    end

    if contents.blank?
      errors[:file] << I18n.t('destinations.import_file.empty_file')
      return false
    end

    line = contents.lines.first
    split_comma, split_semicolon, split_tab = line.split(','), line.split(';'), line.split("\t")
    _split, separator = [[split_comma, ',', split_comma.size], [split_semicolon, ';', split_semicolon.size], [split_tab, "\t", split_tab.size]].max{ |a, b| a[2] <=> b[2] }

    begin
      column_def_any = column_def && column_def.values.any?{ |v| !v.strip.empty? }
      data = CSV.parse(contents, col_sep: separator, headers: !without_header?).collect{ |c|
        if column_def_any
          c.to_a
        else
          c.to_hash
        end
      }
      if data.length > @importer.max_lines + 1
        errors[:file] << I18n.t('destinations.import_file.too_many_lines', n: @importer.max_lines)
        return false
      end
    rescue CSV::MalformedCSVError => e
      errors[:file] << e.message
      return false
    end

    data
  end

  def error_and_format_row(message, row)
    error = message
    if row
      error += ' ' + I18n.t('import.data') + ' '
      row_content = !row.empty? ? (((h = @column_def && @column_def.dup) ? h : {}).each{ |k, _| h[k] = nil }).merge(row) : nil
      if row_content
        row_content[:tags] = row_content[:tags].map(&:label).join(',') if row_content[:tags] && row_content[:tags].is_a?(Enumerable)
        row_content[:tags_visit] = row_content[:tags_visit].map(&:label).join(',') if row_content[:tags_visit] && row_content[:tags_visit].is_a?(Enumerable)
        if @content_code == :html
          error += '<div class="grid-container"><table class="grid">'
          error += '<tr>' + row_content.keys.map{ |a| '<th>' + (@importer.columns[a] && @importer.columns[a][:title] ?
              @importer.columns[a][:title] :
              a.to_s) + (@column_def && @column_def[a] && !@column_def[a].empty? ?
              ' (' + @column_def[a] + ')' : '') + '</th>' }.join('') + '</tr>'
          error += '<tr>' + row_content.values.map{ |a| "<td>#{a}</td>" }.join('') + '</tr>'
          error += '</table></div>'
        else
          error += '[' + row_content.to_a.map{ |a|
            (@column_def && @column_def[a[0]] && !@column_def[a[0]].empty? ?
              '"' + @column_def[a[0]] + '"' :
              @importer.columns[a[0]] && @importer.columns[a[0]][:title] ?
              @importer.columns[a[0]][:title] :
              a[0].to_s) + ": \"#{a[1]}\""
          }.join(', ') + ']'
        end
      else
        error += I18n.t('destinations.import_file.none_column')
      end
    end
    @content_code == :html ? error.html_safe : error
  end
end
