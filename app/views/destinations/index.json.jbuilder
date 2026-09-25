if @customer.destination_import_running?
  job = @customer.job_destination_import
  json.import do
    json.extract! job, :id, :progress, :attempts
    json.error false
    json.message nil
    json.customer_id @customer.id
  end
elsif (failed = @customer.last_failed_destination_import_job)
  json.import do
    json.id failed['id']
    json.attempts 1
    json.progress nil
    json.error true
    json.message failed['error']
    json.customer_id @customer.id
  end
elsif @customer.job_destination_geocoding
  json.geocoding do
    json.extract! @customer.job_destination_geocoding, :id, :progress, :attempts
    json.error !!@customer.job_destination_geocoding.failed_at
    json.customer_id @customer.id
  end
else
  json.tags do
    json.array! @tags, :id, :label, :color, :icon
  end
  json.destinations @destinations, partial: 'destinations/show', as: :destination
end
