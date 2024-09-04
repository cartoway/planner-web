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

  def object_type_cast(object_type, value)
    case object_type
    when 'boolean'
      json_array?(value) ? ActiveRecord::Type::Boolean.new.cast(JSON.parse(value).first) : ActiveRecord::Type::Boolean.new.cast(value)
    when 'integer'
      json_array?(value)? JSON.parse(value).first.to_i : value.to_i
    when 'float'
      json_array?(value) ? JSON.parse(value).first.to_f : value.to_f
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
