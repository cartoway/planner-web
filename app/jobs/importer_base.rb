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
require 'csv'

class ImportBaseError < StandardError; end
class ImportBulkError < StandardError; end
class ImportEmpty < ImportBaseError; end
class ImportTooManyRoutes < ImportBaseError; end
class ImportInvalidRow < ImportBaseError; end
class ImportInvalidRef < ImportBaseError; end

class ImporterBase
  def initialize(customer)
    @customer = customer
    @warnings = []
  end

  # Overrided in importer_destinations.rb
  def uniq_ref(row)
    if row[:ref].is_a?(Array)
      row[:ref].map(&:to_sym)
    else
      row[:ref]&.to_sym
    end
  end

  def import(data, name, synchronous, options)
    @synchronous = synchronous
    dests = false
    refs = Hash.new
    Destination.without_callback(:create, :before, :check_max_destination) do
      Destination.without_callback(:validation, :before, :update_geocode) do
        VehicleUsageSet.without_callback(:create, :before, :check_max_vehicle_usage_set) do
          Customer.transaction do
            before_import(name, data, options)

            dests = data.map.with_index{ |row, line|
              # Switch from locale or custom to internal column name in case of csv
              row = yield(row, line + 1 + (options[:line_shift] || 0))

              next if row.empty? # Skip empty line

              begin
                if (ref = uniq_ref(row))
                  if refs.key?(ref)
                    raise ImportInvalidRef.new(I18n.t("destinations.import_file.#{ref.is_a?(Array) && ref[0].nil? ? 'refs_visit_duplicate' : 'refs_duplicate'}", refs: ref.is_a?(Array) ? ref.compact.join(' | ') : ref))
                  else
                    refs[ref] = nil
                  end
                end

                dest = import_row(name, row, line, options)
                if dest.nil?
                  next
                end

                if !@synchronous && Mapotempo::Application.config.delayed_job_use && dest.respond_to?(:delay_geocode)
                  dest.delay_geocode
                end
                dest
              rescue ImportBaseError => e
                if options[:ignore_errors]
                  @warnings << e unless @warnings.include?(e)
                else
                  raise
                end
              end
            }
            raise ImportEmpty.new I18n.t('import.empty') if dests.all?(&:nil?)
            yield(nil)

            options[:dests] = dests

            after_import(name, options)

            finalize_import(name, options)
          end
        end
      end
    end

    dests
  end

  def warnings
    @warnings
  end

  private

  def need_geocode? location
    location.validate # to nilify blanks
    location.lat.nil? || location.lng.nil?
  end
end
