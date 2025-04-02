module CustomAttributesHelper
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

  def custom_attribute_form_field(form, stop, custom_attribute, prefix)
    field_name = "#{prefix}[custom_attributes][#{custom_attribute.name}]"
    current_value = stop.custom_attributes.key?(custom_attribute.name) ? stop.custom_attributes_typed_hash[custom_attribute.name] : custom_attribute.typed_default_value
    case custom_attribute.object_type_before_type_cast
    when 0
      render partial: 'shared/check_box', locals: { form: form, name: field_name, checked: current_value, help: custom_attribute.description, label: custom_attribute.name, options: { control_col: 'form-switch', label_col: 'd-none', help_label_class: 'd-none'} }
    when 1
      text_area_tag field_name, current_value, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control'
    when 2
      number_field_tag field_name, current_value, step: 1, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control', onkeypress: "return event.charCode >= 48 && event.charCode <= 57"
    when 3
      number_field_tag field_name, current_value, step: :any, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control'
    when 4
      current_value = stop.custom_attributes_typed_hash[custom_attribute.name]
      select_tag field_name, options_for_select(custom_attribute.typed_default_value, current_value), {include_blank: t('web.form.empty_entry'), help: custom_attribute.description, label: custom_attribute.name, class: 'selectpicker form-control' }
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
