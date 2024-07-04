json.extract! destination, :id, :name, :street, :detail, :postalcode, :city, :country, :lat, :lng, :phone_number, :comment, :geocoding_accuracy, :geocoding_level, :geocoding_result
json.ref destination.ref if @customer.enable_references
json.geocoding_level_point destination.point?
json.geocoding_level_house destination.house?
json.geocoding_level_street destination.street?
json.geocoding_level_intersection destination.intersection?
json.geocoding_level_city destination.city?
json.geocoding_result_free destination.geocoding_result.dig('free')
if destination.geocoding_level
  json.geocoding_level_title t('activerecord.attributes.destination.geocoding_level') + ' : ' + t("destinations.form.geocoding_level.#{destination.geocoding_level.to_s}")
end
json.tag_ids do
  json.array! destination.tags.collect(&:id)
end
json.has_no_position !destination.position? ? t('destinations.index.no_position') : false
if @customer.is_editable?
  json.visits do
    json.array! destination.visits do |visit|
      json.extract! visit, :id
      json.ref visit.ref if @customer.enable_references
      json.duration visit.duration_time_with_seconds
      json.duration visit.default_duration_time_with_seconds
      unless @customer.enable_orders
        if @customer.deliverable_units.size == 1
          json.quantity visit.quantities && visit.quantities[@customer.deliverable_units[0].id]
          json.quantity_default @customer.deliverable_units[0].default_quantity
        elsif visit.default_quantities.values.compact.size > 1
          json.multiple_quantities true
        end
        # Hash { id, quantity, icon, label } for deliverable units
        json.quantities visit_quantities(visit, nil)
      end
      json.time_window_start_1 visit.time_window_start_1_absolute_time
      json.time_window_start_1_day number_of_days(visit.time_window_start_1)
      json.time_window_end_1 visit.time_window_end_1_absolute_time
      json.time_window_end_1_day number_of_days(visit.time_window_end_1)
      json.time_window_start_2 visit.time_window_start_2_absolute_time
      json.time_window_start_2_day number_of_days(visit.time_window_start_2)
      json.time_window_end_2 visit.time_window_end_2_absolute_time
      json.time_window_end_2_day number_of_days(visit.time_window_end_2)
      json.priority visit.priority
      json.tag_ids do
        json.array! visit.tags.collect(&:id)
      end
    end
  end
end
