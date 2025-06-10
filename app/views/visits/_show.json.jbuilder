json.destination true

json.extract! @visit.destination, :name, :street, :detail, :postalcode, :city, :country, :comment, :phone_number, :lat, :lng
json.ref @visit.ref || @visit.destination.ref if @visit.destination.customer.enable_references
json.time_window_start_end_1 !!@visit.time_window_start_1 || !!@visit.time_window_end_1
(json.time_window_start_1 @visit.time_window_start_1_time) if @visit.time_window_start_1
(json.time_window_start_1_day number_of_days(@visit.time_window_start_1)) if @visit.time_window_start_1
(json.time_window_end_1 @visit.time_window_end_1_time) if @visit.time_window_end_1
(json.time_window_end_1_day number_of_days(@visit.time_window_end_1)) if @visit.time_window_end_1
json.time_window_start_end_2 !!@visit.time_window_start_2 || !!@visit.time_window_end_2
(json.time_window_start_2 @visit.time_window_start_2_time) if @visit.time_window_start_2
(json.time_window_start_2_day number_of_days(@visit.time_window_start_2)) if @visit.time_window_start_2
(json.time_window_end_2 @visit.time_window_end_2_time) if @visit.time_window_end_2
(json.time_window_end_2_day number_of_days(@visit.time_window_end_2)) if @visit.time_window_end_2
(json.priority @visit.priority) if @visit.priority
(json.link_phone_number current_user.link_phone_number) if current_user.url_click2call
json.visits true
json.visit_id @visit.id
json.destination_id @visit.destination.id
json.color @visit.default_color
tags = @visit.destination.tags | @visit.tags
if !tags.empty?
  json.tags_present do
    json.tags do
      json.array! tags, :label
    end
  end
end
unless @visit.destination.customer.enable_orders
  json.quantities visit_quantities(@visit, nil) do |units|
    json.pickup units[:pickup] if units[:pickup]
    json.delivery units[:delivery] if units[:delivery]
    json.unit_icon units[:unit_icon]
  end
end
json.duration = @visit.default_duration_time_with_seconds
