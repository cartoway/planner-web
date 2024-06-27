class ScheduleType < ActiveRecord::Type::Integer
  def cast(value)
    if value.kind_of?(Time) || value.kind_of?(DateTime)
      value.seconds_since_midnight.to_i
    elsif value.kind_of?(String)
      raise ArgumentError.new(I18n.t('schedule_type.invalid') + " #{value}") if value !~ /\A[0-9: ]*\Z/

      return nil if value.strip.empty?
      value += ':00' if value =~ /\A\d+:\d+\Z/
      ChronicDuration.parse(value, keep_zero: true)
    elsif value.kind_of?(Float) || value.kind_of?(ActiveSupport::Duration)
      raise ArgumentError.new(I18n.t('schedule_type.invalid') + " #{value}") if value && value.to_i < 0

      value.to_i
    else
      raise ArgumentError.new(I18n.t('schedule_type.invalid')) if value && value < 0

      value
    end
  end
end
