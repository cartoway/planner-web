module CustomAttributes
  module FormattingHelper
    def cartoway_deliver_enabled?(customer)
      customer.device.enableds.key?(:deliver)
    end

    def custom_attribute_mobile_visible_configurable?(customer, object_class)
      cartoway_deliver_enabled?(customer) && CustomAttribute.mobile_eligible?(object_class)
    end

    def mobile_custom_attributes_for(customer, stop)
      case stop
      when StopVisit
        customer.custom_attributes.for_stop_visit
      when StopStore
        customer.custom_attributes.for_stop_store
      else
        CustomAttribute.none
      end
    end

    def mobile_visit_custom_attributes_for(customer)
      customer.custom_attributes.for_visit.visible_on_mobile
    end

    def mobile_vehicle_custom_attributes_for(customer)
      customer.custom_attributes.for_vehicle.visible_on_mobile
    end

    def mobile_route_custom_attributes_for(customer)
      customer.custom_attributes.for_route.without_related_field.visible_on_mobile
    end

    def mobile_custom_attribute_value(custom_attribute, object, related_field: nil)
      storage_key = CustomAttribute.storage_key_for(custom_attribute.name, related_field: related_field)
      raw_custom_attributes = object.custom_attributes || {}
      has_value = raw_custom_attributes.key?(storage_key)
      value =
        if has_value
          object.custom_attributes_typed_hash(related_field: related_field)[custom_attribute.name]
        else
          custom_attribute.typed_default_value
        end

      format_custom_attribute_value(custom_attribute, value)
    end

    def format_custom_attribute_value(custom_attribute, value)
      case custom_attribute.object_type
      when 'boolean'
        value ? t('all.value._yes') : t('all.value._no')
      when 'integer'
        return if value.nil?

        number_with_precision(value, precision: 0, delimiter: t('number.format.delimiter'))
      when 'float'
        return if value.nil?

        number_with_precision(value, precision: 2, delimiter: t('number.format.delimiter'), strip_insignificant_zeros: true)
      when 'array'
        value.is_a?(Array) ? value.reject(&:blank?).join(' / ').presence : value
      else
        value
      end
    end

    # Builds display hash for custom attribute in popups.
    # For Route with related_field (e.g. start_route_data, stop_route_data), uses composite storage key.
    def custom_attribute_template(custom_attribute, object, related_field: nil)
      storage_key = if related_field.present? && object.is_a?(Route)
                      CustomAttribute.storage_key_for(custom_attribute.name, related_field: related_field)
                    else
                      custom_attribute.name
                    end
      raw_custom_attributes = object.custom_attributes || {}
      has_value = raw_custom_attributes.key?(storage_key)
      current_value =
        if has_value
          object_type_cast(custom_attribute.object_type, raw_custom_attributes[storage_key])
        else
          custom_attribute.typed_default_value
        end
      case custom_attribute.object_type_before_type_cast
      when 0
        { html: "<li><i class='fa fa-file-lines fa-fw'></i> #{custom_attribute.name} : <i class='fa #{current_value ? 'fa-circle-check' : 'fa-circle-xmark'} fa-fw'></i></li>" }
      when 4
        label = "<li><i class='fa fa-file-lines fa-fw'></i> #{custom_attribute.name} :"
        { html: has_value ? "#{label} #{current_value}</li>" : "#{label}</li>" }
      else
        { html: "<li><i class='fa fa-file-lines fa-fw'></i> #{custom_attribute.name} : #{current_value}</li>" }
      end
    end

    def object_type_cast(object_type, value)
      case object_type
      when 'boolean'
        json_array?(value) ? ActiveRecord::Type::Boolean.new.cast(JSON.parse(value).first) : value && ActiveRecord::Type::Boolean.new.cast(value)
      when 'integer'
        json_array?(value)? JSON.parse(value).first.to_i : value&.to_i
      when 'float'
        json_array?(value) ? JSON.parse(value).first.to_f : value&.to_f
      when 'array'
        json_array?(value) && JSON.parse(value) || [""]
      else
        json_array?(value) ? JSON.parse(value).first : value
      end
    end

    def json_array?(value)
      valid_json?(value) && JSON.parse(value).is_a?(Array)
    end

    def valid_json?(json)
      JSON.parse(json)
      true
    rescue JSON::ParserError, TypeError
      false
    end
  end
end
