class CustomAttribute < ApplicationRecord
  default_scope { order(:id) }

  validates :name, uniqueness: { scope: [:object_class, :customer_id, :related_field] }
  validates :related_field, inclusion: { in: ->(ca) { ca.valid_related_fields }, allow_nil: true }
  before_validation :default_value_to_type

  belongs_to :customer

  # Virtual attribute for the combined object_class and related_field select
  attr_accessor :object_class_with_related_field

  before_validation :parse_object_class_with_related_field

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
    stop_visit: 2,
    stop_store: 3,
    route: 4,
  }

  RELATED_FIELDS = {
    route: [:start_route_data, :stop_route_data]
  }.freeze

  scope :for_vehicle, -> { where(object_class: :vehicle) }
  scope :for_visit, -> { where(object_class: :visit) }
  scope :for_stop_visit, -> { where(object_class: :stop_visit) }
  scope :for_stop_store, -> { where(object_class: :stop_store) }
  scope :for_export_stops_unique_by_name, -> {
    export_stops = where(object_class: [:stop_visit, :stop_store, :route])
    export_stops.where(id: export_stops.unscope(:order).group(:name).select("MIN(id) as id"))
  }
  scope :for_route, -> { where(object_class: :route) }
  scope :for_related_field, ->(field) { where(related_field: field) }
  scope :without_related_field, -> { where(related_field: nil) }

  auto_strip_attributes :name
  validates :name, presence: true
  validates :name, format: { without: /:/, message: :cannot_contain_colon }

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

  def display_default_value
    case object_type
    when 'boolean'
      ActiveRecord::Type::Boolean.new.cast(default_value)
    when 'integer'
      default_value.to_i
    when 'float'
      default_value.to_f
    when 'array'
      default_value && JSON.parse(default_value)&.join(' / ') || []
    else
      default_value
    end
  end

  def self.ordered_object_classes
    (%w[vehicle visit] | object_classes.keys) # Set Union to be sure no object class is forgotten
  end

  def self.related_fields_for(object_class)
    RELATED_FIELDS[object_class.to_sym] || []
  end

  def self.object_class_options_with_related_fields
    options = []
    ordered_object_classes.each do |object_class|
      related_fields = related_fields_for(object_class)
      if related_fields.empty?
        options << object_class
      else
        related_fields.each do |related_field|
          options << "#{object_class}:#{related_field}"
        end
      end
    end
    options
  end

  def self.parse_object_class_value(value)
    return [nil, nil] if value.blank?

    if value.include?(':')
      parts = value.split(':', 2)
      [parts[0], parts[1].presence]
    else
      [value, nil]
    end
  end

  # Composite key for custom_attributes storage: "related_field:name" when related_field present, else "name"
  def self.storage_key_for(name, related_field: nil)
    related_field.present? ? "#{related_field}:#{name}" : name.to_s
  end

  def valid_related_fields
    return [] unless object_class
    self.class.related_fields_for(object_class).map(&:to_s)
  end

  def related_fields?
    valid_related_fields.any?
  end

  private

  def parse_object_class_with_related_field
    return unless object_class_with_related_field.present?

    object_class, related_field = self.class.parse_object_class_value(object_class_with_related_field)
    self.object_class = object_class if object_class.present?
    self.related_field = related_field
  end

  def default_value_to_type
    return if new_record? || !object_type_changed?

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
