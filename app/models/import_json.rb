# Copyright © Mapotempo, 2016
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

class ImportJson
  include ActiveModel::Model
  include ActiveRecord::AttributeAssignment
  extend ActiveModel::Translation

  attr_accessor :importer, :replace, :json

  def replace=(value)
    @replace = ValueToBoolean.value_to_boolean(value)
  end

  def import(synchronous = false)
    data = @importer.json_to_rows json
    if data
      begin
        last_row = nil
        Customer.transaction do
          keys = @importer.columns.keys

          rows = @importer.import(data, nil, synchronous, ignore_errors: false, replace: replace) { |row, _line|
            if row
              r, row = row, {}
              r.each{ |k, v|
                ks = k.to_sym
                if keys.include?(ks)
                  row[ks] = v
                end
              }
            end
            last_row = row

            row
          }
          last_row = nil
          @importer.rows_to_json rows
        end
      rescue => e
        raise e if Rails.env.test? && !e.is_a?(ImportBaseError) && !e.is_a?(Exceptions::OverMaxLimitError)
        message = e.is_a?(ImportInvalidRow) ? I18n.t('import.data_erroneous.json') + ', ' + e.message : e.message
        errors.add(:base, message + (last_row ? ' [' + last_row.to_a.collect{ |a| "#{a[0]}: \"#{a[1]}\"" }.join(', ') + ']' : ''))
        Rails.logger.error e.message
        Rails.logger.error e.backtrace.join("\n")
        return false
      end
    end
  end
end
