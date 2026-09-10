module CustomAttributesHelper
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

    case custom_attribute.object_type
    when 'boolean'
      value ? t('all.value._yes') : t('all.value._no')
    else
      value
    end
  end

  def custom_attribute_default_value_form_field(object_type, typed_default_value)
    case object_type
    when 'boolean'
      render partial: 'shared/check_box', locals: { name: 'custom_attribute[default_value]', checked: typed_default_value }
    when 'string'
      text_area_tag 'custom_attribute[default_value]', typed_default_value, class: 'form-control'
    when 'integer'
      number_field_tag 'custom_attribute[default_value]', typed_default_value, stop: 1, class: 'form-control', onkeypress: "return event.charCode >= 48 && event.charCode <= 57"
    when 'float'
      number_field_tag 'custom_attribute[default_value]', typed_default_value, step: :any, class: 'form-control'
    end
  end

  def custom_attribute_form_field(form, object, custom_attribute, prefix, related_field: nil)
    # Use composite key (related_field:name) for Route to distinguish start vs stop
    storage_key = CustomAttribute.storage_key_for(custom_attribute.name, related_field: related_field)
    field_name = "#{prefix}[custom_attributes][#{storage_key}]"
    typed_hash = if related_field.present?
      object.custom_attributes_typed_hash(related_field: related_field)
    else
      object.custom_attributes_typed_hash
    end
    has_value = object.custom_attributes.key?(storage_key)
    current_value = has_value ? typed_hash[custom_attribute.name] : custom_attribute.typed_default_value
    placeholder = custom_attribute.typed_default_value || t('web.form.empty_entry')
    case custom_attribute.object_type_before_type_cast
    when 0
      render partial: 'shared/check_box', locals: { form: form, name: field_name, checked: current_value, help: custom_attribute.description, label: custom_attribute.name, options: { control_col: 'form-switch', label_col: 'd-none', help_label_class: 'd-none'} }
    when 1
      options = { help: custom_attribute.description, label: custom_attribute.name, class: 'form-control' }
      options[:placeholder] = placeholder if placeholder
      text_area_tag field_name, current_value, options
    when 2
      options = { step: 1, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control', onkeypress: "return event.charCode >= 48 && event.charCode <= 57" }
      options[:placeholder] = placeholder if placeholder
      number_field_tag field_name, current_value, options
    when 3
      options = { step: :any, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control' }
      options[:placeholder] = placeholder if placeholder
      number_field_tag field_name, current_value, options
    when 4
      current_value = typed_hash[custom_attribute.name]
      select_tag field_name, options_for_select(custom_attribute.typed_default_value, current_value), {include_blank: t('web.form.empty_entry'), help: custom_attribute.description, label: custom_attribute.name, class: 'selectpicker form-control' }
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
      { html: "<li><i class='fa fa-file-lines fa-fw'></i> #{custom_attribute.name} : #{has_value ? current_value : nil}</li>" }
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
