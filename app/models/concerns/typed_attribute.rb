module TypedAttribute
  extend ActiveSupport::Concern

  class_methods do
    def typed_attr(current_attribute)
      define_method("#{current_attribute}_has_key?") do |name, related_field: nil|
        storage_key = CustomAttribute.storage_key_for(name, related_field: related_field)
        send(current_attribute).key?(storage_key)
      end

      define_method("#{current_attribute}_typed_hash") do |related_field: nil|
        typed_hash_cache = instance_variable_get(:@_typed_attr_hash_cache) || {}
        cache_key = [current_attribute, related_field]
        if typed_hash_cache.key?(cache_key)
          return typed_hash_cache[cache_key]
        end

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

        reference_attributes =
          if customer.association(current_attribute).loaded?
            customer.send(current_attribute).select do |custom_attribute|
              next false unless custom_attribute.object_class_before_type_cast == current_type

              if related_field.present?
                custom_attribute.related_field == related_field.to_s
              elsif related_field.nil? && self.is_a?(Route)
                custom_attribute.related_field.nil?
              else
                true
              end
            end
          else
            scoped_attributes = customer.send(current_attribute).where(object_class: current_type)
            if related_field.present?
              scoped_attributes = scoped_attributes.where(related_field: related_field)
            elsif related_field.nil? && self.is_a?(Route)
              # For Route, if related_field is explicitly nil, only get attributes without related_field
              scoped_attributes = scoped_attributes.where(related_field: nil)
            end
            scoped_attributes
          end

        current_attributes = send(current_attribute) || {}
        typed_hash = Hash[reference_attributes.map { |r_a|
          storage_key = CustomAttribute.storage_key_for(r_a.name, related_field: related_field)
          raw_value = current_attributes[storage_key]
          [r_a.name, typed_value(r_a.object_type, raw_value || r_a.default_value)]
        }]

        typed_hash_cache[cache_key] = typed_hash
        instance_variable_set(:@_typed_attr_hash_cache, typed_hash_cache)
        typed_hash
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
