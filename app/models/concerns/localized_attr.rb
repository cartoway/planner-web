require "#{Rails.application.root}/lib/localized_values.rb"

module LocalizedAttr
  extend ActiveSupport::Concern

  class_methods do
    include ActionView::Helpers::NumberHelper

    def attr_localized(*names)
      names.each do |name|
        define_method("#{name}=") do |value|
          if value.is_a? Hash
            value.each{ |k, v|
              value[k] = self.class.to_delocalized_decimal(v) if v.is_a?(String)
            }
          elsif value.is_a? String
            value = self.class.to_delocalized_decimal(value)
          end
          self[name] = value
        end
        define_method("localized_#{name}") do
          r = send(name)
          if r.is_a? QuantityAttr::QuantityHash
            rr = QuantityAttr::QuantityHash.new
            r.each{ |k, v|
              rr[k] = v.is_a?(Float) ? self.class.localize_numeric_value(v) : v
            }
            rr
          elsif r.is_a? Float
            self.class.localize_numeric_value r
          else
            r
          end
        end
      end
    end

    def to_delocalized_decimal(str)
      delimiter = I18n.t('number.format.delimiter')
      separator = I18n.t('number.format.separator')

      str = str.gsub(separator, '.') if str
      # Do not replace delimiter if it's a point. Because the default separator is a point.
      str = str.gsub(/#{delimiter}([0-9]{3})/, '\1') if str && I18n.t('number.format.delimiter') != '.'

      return str
    end

    def localize_numeric_value(float)
      float ? LocalizedValues.localize_numeric_value(float) : ''
    end
  end
end
