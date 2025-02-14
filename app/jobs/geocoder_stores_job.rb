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
GeocoderStoresJobStruct ||= Job.new(:customer_id)
class GeocoderStoresJob < GeocoderStoresJobStruct
  def perform
    customer = Customer.find(customer_id)
    Delayed::Worker.logger.info("GeocoderStoresJob perform", customer_id: customer_id)
    count = customer.stores.where(lat: nil).count
    i = 0
    customer.stores.not_positioned.find_in_batches(batch_size: 50){ |stores|
      Store.transaction do
        geocode_args = stores.collect(&:geocode_args)
        begin
          results = Planner::Application.config.geocoder.code_bulk(geocode_args)
          stores.zip(results).each { |store, result|
            store.geocode_result(result) if result
            store.save!
            i += 1
          }
        rescue GeocodeError # avoid stop import because of geocoding job
        end
        job_progress_save({ 'first_progression': (i * 100.0) / count, status: 'working' })
        Delayed::Worker.logger.info("GeocoderStoresJob", customer_id: customer_id, progress: @job.progress)
      end
    }
    job_progress_save({ 'first_progression': 100, 'completed': true })
  rescue => e
    puts e.message
    puts e.backtrace.join("\n")
    raise e
  end
end
