module TypedAttribute
  extend ActiveSupport::Concern

  class_methods do
    def typed_attr(current_attribute)
      define_method("#{current_attribute}_typed_values") do
        object_attributes = self.customer.send(current_attribute).where(object_class: self.class.to_s)
        send(current_attribute).map { |key, value|
          typed_value(object_attributes.where({ name: key }).first.object_type, value)
        }
      end

      define_method("#{current_attribute}_typed_hash") do
        object_attributes = self.customer.send(current_attribute).where(object_class: self.class.to_s)
        Hash[send(current_attribute).map { |key, value|
          [key, typed_value(object_attributes.where({ name: key }).first.object_type, value)]
        }]
      end
    end
  end

  private

  def typed_value(type, value)
    case type
    when "boolean"
      ActiveRecord::Type::Boolean.new.type_cast_from_user(value)
    when "integer"
      value.to_i
    when "float"
      value.to_f
    else
      value
    end
  end
end
