if @customer.job_destination_import
  json.import do
    json.extract! @customer.job_destination_import, :id, :progress, :attempts
    json.error !!@customer.job_destination_import.failed_at
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
