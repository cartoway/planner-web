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
