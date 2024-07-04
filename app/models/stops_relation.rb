class StopsRelation < ActiveRecord::Base
  belongs_to :customer

  belongs_to :current, class_name: 'Visit'
  belongs_to :successor, class_name: 'Visit'

  # Belonging to only one relation is only a limitation for the pickup_delivery relation
  # Due to the implementation of such constraint in VRP solvers
  validates :current_id, uniqueness: { scope: :customer_id }, if: :pickup_delivery?
  validates :successor_id, uniqueness: { scope: :customer_id }, if: :pickup_delivery?
  validate :pickup_delivery_relation_uniqueness
  validate :validate_different_visits

  enum relation_type: {
    pickup_delivery: 0,
    ordered: 1,
    sequence: 2,
    same_vehicle: 3
  }

  amoeba do
    enable
  end

  def validate_different_visits
    return unless current == successor

    errors.add(:successor, :same_visit, current: current.to_s)
  end

  def pickup_delivery_relation_uniqueness
    return unless pickup_delivery? && (self.class.find_by(current: successor) || self.class.find_by(successor: current))

    errors.add(:base, I18n.t('activerecord.errors.models.relation.pickup_delivery_uniqueness'))
  end
end
