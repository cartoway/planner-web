module TypedAttribute
  extend ActiveSupport::Concern

  class_methods do
    def typed_attr(current_attribute)
      define_method("#{current_attribute}_typed_hash") do
        customer =
          if self.respond_to?(:customer)
            self.customer
          elsif self.is_a?(Stop)
            self.visit.destination.customer
          end

        current_type =
          if self.is_a?(Stop)
            CustomAttribute.object_classes['stop']
          else
            CustomAttribute.object_classes[self.class.to_s.downcase]
          end

        reference_attributes = customer.send(current_attribute).where(object_class: current_type)
        current_attributes = send(current_attribute)
        rhash = Hash[reference_attributes.map{ |r_a|
          [r_a.name, typed_value(r_a.object_type, current_attributes[r_a.name] || r_a.default_value)]
        }]
        rhash
      end
    end
  end

  private

  def typed_value(type, value)
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
