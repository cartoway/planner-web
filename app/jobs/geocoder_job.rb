GeocoderJobStruct ||= Job.new(:customer_id, :planning_ids)
class GeocoderJob < GeocoderJobStruct
  def job_perform
    customer = Customer.find(customer_id)
    Delayed::Worker.logger.info("GeocoderJob perform", customer_id: customer_id)
    destination_count = customer.destinations.not_positioned.count
    store_count = customer.stores.not_positioned.count
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
        rescue GeocodeError # avoid stop import because of geocoding job # rubocop:disable Lint/SuppressedException
        end
        job_progress_save({ 'first_progression': i * 100.0 / (destination_count + store_count), status: 'working' })
        Delayed::Worker.logger.info("GeocoderJob", customer_id: customer_id, progress: @job.progress)
      end
    }

    customer.stores.not_positioned.find_in_batches(batch_size: 50){ |stores|
      Store.transaction do
        geocode_args = stores.collect(&:geocode_args)
        begin
          results = Planner::Application.config.geocoder.code_bulk(geocode_args)
          stores.zip(results).each { |store, result|
            store.geocode_result(result) if result
            store.outdated
            i += 1
          }
          Store.import(
            stores.to_ary,
            validate: true,
            on_duplicate_key_update: {
              columns: %i[geocoding_result geocoder_version geocoded_at lat lng geocoding_accuracy geocoding_level]
            }
          )
        rescue GeocodeError # avoid stop import because of geocoding job # rubocop:disable Lint/SuppressedException
        end
        job_progress_save({ 'first_progression': i * 100.0 / (destination_count + store_count), status: 'working' })
        Delayed::Worker.logger.info("GeocoderJob", customer_id: customer_id, progress: @job.progress)
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
  rescue StandardError => e
    puts e.message
    puts e.backtrace.join("\n")
    raise e
  end
end
