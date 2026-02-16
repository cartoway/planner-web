module TypedAttribute
  extend ActiveSupport::Concern

  class_methods do
    def typed_attr(current_attribute)
      define_method("#{current_attribute}_has_key?") do |name, related_field: nil|
        storage_key = CustomAttribute.storage_key_for(name, related_field: related_field)
        send(current_attribute).key?(storage_key)
      end

      define_method("#{current_attribute}_typed_hash") do |related_field: nil|
        customer =
          if self.respond_to?(:customer)
            self.customer
          elsif self.is_a?(Stop)
            self.route.planning.customer
          elsif self.is_a?(Route)
            self.planning.customer
          end

        current_type =
          CustomAttribute.object_classes[self.class.to_s.snakecase]

        reference_attributes = customer.send(current_attribute).where(object_class: current_type)
        if related_field.present?
          reference_attributes = reference_attributes.where(related_field: related_field)
        elsif related_field.nil? && self.is_a?(Route)
          # For Route, if related_field is explicitly nil, only get attributes without related_field
          reference_attributes = reference_attributes.where(related_field: nil)
        end

        current_attributes = send(current_attribute) || {}
        rhash = Hash[reference_attributes.map{ |r_a|
          storage_key = CustomAttribute.storage_key_for(r_a.name, related_field: related_field)
          raw_value = current_attributes[storage_key]
          [r_a.name, typed_value(r_a.object_type, raw_value || r_a.default_value)]
        }]
        rhash
      end
    end
  end

  private

  def typed_value(type, value)
    return if value.blank?

    case type
    when 'boolean'
      ActiveRecord::Type::Boolean.new.cast(value)
    when 'integer'
      value.to_i
    when 'float'
      value.to_f
    else
      value
    end
  end
end
