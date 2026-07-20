# frozen_string_literal: true

require 'coerce'
require 'value_to_boolean'

# Casts CSV (string) import values using column `:type` metadata before activerecord-import.
# Already-typed API/JSON values pass through when compatible.
class ImportRowCaster
  SUPPORTED_TYPES = %i[string integer float boolean yes_no hour date tags].freeze

  def self.cast_row!(row, columns)
    return row if row.nil? || columns.blank?

    columns.each do |key, definition|
      type = definition[:type]
      next if type.nil? || !row.key?(key)

      row[key] = cast_value(row[key], type, key)
    end
    row
  end

  def self.cast_value(value, type, key = nil)
    return value if value.nil?
    return nil if value.is_a?(String) && value.strip.empty?

    case type.to_sym
    when :string
      value.is_a?(String) ? value : value.to_s
    when :tags
      # JSON/API may already provide label arrays or tag ids
      return value if value.is_a?(Array)

      value.is_a?(String) ? value : value.to_s
    when :integer
      cast_integer(value, key)
    when :float
      cast_float(value, key)
    when :boolean, :yes_no
      ValueToBoolean.value_to_boolean(value, nil)
    when :hour
      cast_hour(value, key)
    when :date
      cast_date(value, key)
    else
      value
    end
  rescue ArgumentError, TypeError
    raise ImportInvalidRow, I18n.t('import.invalid_typed_value', column: key, value: value, type: type)
  end

  def self.cast_integer(value, key)
    return value if value.is_a?(Integer)
    return value.to_i if value.is_a?(Numeric) && value.to_i == value

    Integer(value.to_s.strip)
  rescue ArgumentError, TypeError
    # Accept localized floats that represent whole numbers (e.g. "2,0")
    float_value = CoerceFloatString.parse(value)
    raise ArgumentError if float_value.nil? || float_value != float_value.to_i

    float_value.to_i
  end

  def self.cast_float(value, key)
    CoerceFloatString.parse(value)
  end

  def self.cast_hour(value, key)
    ScheduleType.new.cast(value)
  end

  def self.cast_date(value, key)
    return value if value.is_a?(Date)

    date_string = value.to_s.strip
    parsed_date = Date.strptime(date_string, I18n.t('destinations.import_file.format.date'))
    return parsed_date if parsed_date.year > 100

    Date.strptime(date_string, I18n.t('destinations.import_file.format.date_short'))
  end
  private_class_method :cast_integer, :cast_float, :cast_hour, :cast_date
end
