module CustomAttributes
  module FormHelper
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
  end
end
