# Copyright © Mapotempo, 2013-2016
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
GeocoderDestinationsJobStruct ||= Job.new(:customer_id, :planning_ids)
class GeocoderDestinationsJob < GeocoderDestinationsJobStruct
  def perform
    customer = Customer.find(customer_id)
    Delayed::Worker.logger.info("GeocoderDestinationsJob perform", customer_id: customer_id)
    count = customer.destinations.not_positioned.count
    i = 0
    customer.destinations.includes_visits.not_positioned.find_in_batches(batch_size: 50){ |destinations|
      Destination.transaction do
        geocode_args = destinations.collect(&:geocode_args)
        begin
          results = Planner::Application.config.geocoder.code_bulk(geocode_args)
          destinations.zip(results).each { |destination, result|
            destination.geocode_result(result) if result
            destination.visits.each{ |v| v.outdated }
            i += 1
          }
          Destination.import(
            destinations.to_ary,
            validate: true,
            on_duplicate_key_update: {
              columns: %i[geocoding_result geocoder_version geocoded_at lat lng geocoding_accuracy geocoding_level]
            }
          )
        rescue GeocodeError # avoid stop import because of geocoding job
        end
        job_progress_save({ 'first_progression': i * 100.0 / count, status: 'working' })
        Delayed::Worker.logger.info("GeocoderDestinationsJob", customer_id: customer_id, progress: @job.progress)
      end
    }
    customer.reload

    Destination.transaction do
      unless !planning_ids || planning_ids.empty?
        customer.plannings.where(id: planning_ids).each{ |planning|
          planning.compute_saved
        }
      end
    end
    job_progress_save({ 'first_progression': 100, 'completed': true })
  rescue => e
    puts e.message
    puts e.backtrace.join("\n")
    raise e
  end
end
