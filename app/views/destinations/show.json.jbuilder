json.extract! @destination, :name, :street, :detail, :postalcode, :city, :country, :lat, :lng, :comment, :phone_number, :geocoding_accuracy, :geocoding_level
json.destination_id @destination.id
json.error !@destination.position?
if @customer.is_editable?
  json.visits @destination.visits do |visit|
    json.extract! visit, :id, :tag_ids
    json.quantities visit_quantities(visit, nil) # Hash { id, quantity, icon, label } for deliverable units
    json.index_visit (@destination.visits.index(visit) + 1) if @destination.visits.size > 1
    json.ref visit.ref if @customer.enable_references
    duration = visit.default_duration_time_with_seconds
    json.duration duration
    json.duration duration
    json.time_window_start_end_1 !!visit.time_window_start_1 || !!visit.time_window_end_1
    json.time_window_start_1 visit.time_window_start_1_time
    (json.time_window_start_1_day number_of_days(visit.time_window_start_1)) if visit.time_window_start_1
    json.time_window_end_1 visit.time_window_end_1_time
    (json.time_window_end_1_day number_of_days(visit.time_window_end_1)) if visit.time_window_end_1
    json.time_window_start_end_2 !!visit.time_window_start_2 || !!visit.time_window_end_2
    json.time_window_start_2 visit.time_window_start_2_time
    (json.time_window_start_2_day number_of_days(visit.time_window_start_2)) if visit.time_window_start_2
    json.time_window_end_2 visit.time_window_end_2_time
    (json.time_window_end_2_day number_of_days(visit.time_window_end_2)) if visit.time_window_end_2
    json.priority visit.priority
    tags = visit.tags | @destination.tags
    unless tags.empty?
      json.tags_present do
        json.tags do
          json.array! tags, :label
        end
      end
    end
  end
end
