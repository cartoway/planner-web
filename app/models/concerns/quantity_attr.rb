module QuantityAttr
  extend ActiveSupport::Concern

  class QuantityHash < Hash
    def self.[](*args)
      hash = new
      if args.size == 1 && (args.first.is_a?(Hash) || args.first.is_a?(Array))
        args.first.each{ |key, value| hash.store(key.to_s, value) }
      else
        args.each_slice(2){ |key, value| hash.store(key.to_s, value) }
      end
      hash.transform_keys!{ |key|
        begin
          Integer(key)
        rescue StandardError
          # The error return is delegated to the validation
          key
        end
      }
      hash
    end

    def key?(key)
      super(key) || super(key.to_s)
    end

    def []=(key, value)
      super(key, value)

      # Synchronize with the model without calling the accessor
      if @model && @field
        @model.write_attribute(@field, self)
      end
    end

    def delete_if(&block)
      super { |key, value| block.call(key, value) }
    end

    def dup
      QuantityHash[self]
    end
  end

  class_methods do
    def quantity_attr(*fields)
      @quantity_attrs = fields.map(&:to_sym)
      before_validation :convert_quantity_values

      @quantity_attrs.each { |field|
        define_method("#{field}") do
          quantities = super()

          return QuantityHash.new if quantities.blank?

          if @validating
            quantities.instance_variable_set(:@validating, @validating)
          elsif errors.none?
            quantities.transform_keys!(&:to_i)
            quantities.transform_values! { |v| v.present? ? Float(v) : nil }
          end

          hash = QuantityHash[quantities]
          # Store the QuantityHash instance so we can reuse it
          instance_variable_set("@#{field}_quantity_hash", hash)
          # Pass references to the model and field
          hash.instance_variable_set(:@model, self)
          hash.instance_variable_set(:@field, field)
          hash
        end
      }
    end

    def quantity_attrs
      @quantity_attrs || []
    end
  end

  private

  def convert_quantity_values
    @validating = true
    self.class.quantity_attrs.each do |field|
      quantities = self.send(field)
      next unless quantities.present?

      if quantities.is_a?(Hash) || quantities.is_a?(QuantityHash)
        quantities.each { |key, value|
          next if value.blank?

          new_value =
            begin
              Float(value)
            rescue StandardError => e
              self.errors.add field, :not_float if e.is_a?(ArgumentError) || e.is_a?(TypeError)
              return false
            end
          if new_value < 0
            self.errors.add field, :negative_value, **{value: value}
            return false
          end
          begin
            Integer(key)
            quantities[key] = new_value
          rescue StandardError => e
            self.errors.add field, :not_integer if e.is_a?(ArgumentError) || e.is_a?(TypeError)
            return false
          end
        }
      end
    end
  ensure
    @validating = false
  end
end
