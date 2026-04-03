# Copyright © Mapotempo, 2017
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
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  before_save :set_creation_date

  def set_creation_date
    # Align precision of second to Postgres default. Avoid object change when reload from database.
    self.updated_at ||= DateTime.now.iso8601(6)
    self.created_at ||= self.updated_at
  end

  def import_attributes
    self.attributes.slice(*self.class.column_names).except('lock_version', 'created_at', 'updated_at')
  end

  def symbolized_attributes
    self.attributes.slice(*self.class.column_names).symbolize_keys
  end

  # Import records in batches and return all IDs
  def self.import_in_batches(attributes_array, batch_size: 1000, **options)
    return [] if attributes_array.empty?

    all_ids = []
    attributes_array.each_slice(batch_size) do |batch|
      import_result = self.import(batch, **options)
      all_ids.concat(import_result.ids) if import_result.ids
    end
    all_ids
  end

  # Execute a transaction while blocking SELECT queries
  # This ensures all data is already loaded in memory before the transaction
  def transaction_without_selects(&block)
    connection = ActiveRecord::Base.connection

    # Store original methods
    original_methods = {}
    methods_to_override = [:execute, :select_all, :select_one, :select_value, :select_values]

    # Override methods to block SELECT queries
    methods_to_override.each do |method_name|
      next unless connection.respond_to?(method_name)
      original_method = connection.method(method_name)
      original_methods[method_name] = original_method

      connection.define_singleton_method(method_name) do |sql, *args|
        sql_string = sql.is_a?(String) ? sql : sql.to_sql
        if sql_string.strip.match?(/^\s*SELECT/i)
          raise "SELECT queries are not allowed during transaction_without_selects. Attempted query: #{sql_string[0..200]}"
        end
        original_method.call(sql, *args)
      end
    end

    begin
      self.class.transaction do
        yield
      end
    ensure
      # Restore original methods
      original_methods.each do |method_name, original_method|
        connection.define_singleton_method(method_name, original_method)
      end
    end
  end
end
