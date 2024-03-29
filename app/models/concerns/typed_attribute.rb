module TypedAttribute
  extend ActiveSupport::Concern

  class_methods do
    def typed_attr(current_attribute)
      define_method("#{current_attribute}_typed_hash") do
        reference_attributes = self.customer.send(current_attribute).where(object_class: self.class.to_s)
        current_attributes = send(current_attribute)
        Hash[reference_attributes.map{ |r_a|
          [r_a.name, typed_value(r_a.object_type, current_attributes[r_a.name] || r_a.default_value)]
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
