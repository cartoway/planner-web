module CustomAttributes
  module DeliveryNoteHelper
    # ✓/✗ for booleans; integer/float already match quantity formatting
    def delivery_note_custom_attribute_value(custom_attribute, object, related_field: nil)
      value = delivery_note_custom_attribute_effective_value(custom_attribute, object, related_field: related_field)
      return value ? '✓' : '✗' if custom_attribute.object_type == 'boolean'

      format_custom_attribute_value(custom_attribute, value)
    end

    def delivery_note_custom_attribute_displayable?(custom_attribute, object, related_field: nil)
      value = delivery_note_custom_attribute_effective_value(custom_attribute, object, related_field: related_field)
      custom_attribute.boolean? ? !value.nil? : value.present?
    end

    def delivery_note_custom_attribute_effective_value(custom_attribute, object, related_field: nil)
      storage_key = CustomAttribute.storage_key_for(custom_attribute.name, related_field: related_field)
      raw = object.custom_attributes || {}

      if raw.key?(storage_key) && (custom_attribute.boolean? || raw[storage_key].present?)
        if custom_attribute.boolean?
          ActiveRecord::Type::Boolean.new.cast(raw[storage_key])
        else
          object.custom_attributes_typed_hash(related_field: related_field)[custom_attribute.name]
        end
      elsif delivery_note_custom_attribute_default_set?(custom_attribute)
        custom_attribute.typed_default_value
      end
    end

    def delivery_note_custom_attribute_default_set?(custom_attribute)
      # false.blank? is true — treat boolean defaults explicitly
      return !custom_attribute.default_value.nil? if custom_attribute.boolean?

      custom_attribute.default_value.present?
    end
  end
end
