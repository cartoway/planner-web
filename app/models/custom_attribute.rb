class CustomAttribute < ApplicationRecord
  default_scope { order(:id) }

  validates :name, uniqueness: { scope: [:object_class, :customer_id] }

  belongs_to :customer

  enum object_type: {
    boolean: 0,
    string: 1,
    integer: 2,
    float: 3
  }

  enum object_class: {
    vehicle: 0
  }

  auto_strip_attributes :name
  validates :name, presence: true

  def typed_default_value
    case object_type
    when boolean
      default_value.to_bool
    when integer
      default_value.to_i
    when float
      default_value.to_f
    else
      default_value
    end
  end
end
