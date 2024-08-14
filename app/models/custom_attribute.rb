class CustomAttribute < ApplicationRecord
  default_scope { order(:id) }

  validates :name, uniqueness: { scope: [:object_class, :customer_id] }
  before_validation :default_value_to_type

  belongs_to :customer

  enum object_type: {
    boolean: 0,
    string: 1,
    integer: 2,
    float: 3,
    array: 4
  }

  enum object_class: {
    vehicle: 0,
    visit: 1,
    stop: 2
  }

  auto_strip_attributes :name
  validates :name, presence: true

  def typed_default_value
    case object_type
    when 'boolean'
      ActiveRecord::Type::Boolean.new.cast(default_value)
    when 'integer'
      default_value.to_i
    when 'float'
      default_value.to_f
    when 'array'
      default_value && JSON.parse(default_value) || []
    else
      default_value
    end
  end

  def self.ordered_object_classes
    (%w[stop vehicle visit] | object_classes.keys) # Set Union to be sure no object class is forgotten
  end

  private

  def default_value_to_type
    return unless object_type_changed?

    case object_type
    when 'boolean'
      self.default_value = 0 unless [0, 1].include?(default_value)
    when 'integer'
      self.default_value.respond_to?(:each) ? 0 : default_value&.to_i
    when 'float'
      self.default_value.respond_to?(:each) ? 0 : default_value&.to_f
    when 'array'
      self.default_value = [''] unless default_value.respond_to?(:each)
    when 'string'
      self.default_value = '' unless default_value.is_a?(String)
    end
  end
end
