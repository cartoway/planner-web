# Copyright © Mapotempo, 2016
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class Visit < ApplicationRecord
  default_scope { order(:id) }

  belongs_to :destination, inverse_of: :visits
  has_many :relation_currents, class_name: 'Relation', foreign_key: 'current_id', dependent: :delete_all, validate: false
  has_many :relation_successors, class_name: 'Relation', foreign_key: 'successor_id', dependent: :delete_all, validate: false
  has_many :stop_visits, inverse_of: :visit
  has_many :orders, inverse_of: :visit, dependent: :delete_all

  has_many :tag_visits
  has_many :tags, through: :tag_visits, after_add: :update_tags_track, after_remove: :update_tags_track

  delegate :customer, :lat, :lng, :name, :street, :postalcode, :city, :state, :country, :detail, :comment, :phone_number, to: :destination
  serialize :quantities, DeliverableUnitQuantity
  serialize :quantities_operations, DeliverableUnitOperation

  nilify_blanks
  validates :destination, presence: true

  scope :positioned, -> { joins(:destination).merge(Destination.positioned) }
  scope :includes_destinations, -> { includes([:tags, destination: :tags]) }

  enum force_position: {
    neutral: 0,
    always_first: 1,
    never_first: 2,
    always_final: 3
  }

  include TimeAttr
  attribute :time_window_start_1, ScheduleType.new
  attribute :time_window_end_1, ScheduleType.new
  attribute :time_window_start_2, ScheduleType.new
  attribute :time_window_end_2, ScheduleType.new
  attribute :duration, ScheduleType.new
  time_attr :time_window_start_1, :time_window_end_1, :time_window_start_2, :time_window_end_2, :duration

  validate :time_window_end_1_after_time_window_start_1
  validates :time_window_end_1, presence: true, if: ->(visit) { visit.time_window_start_2 || visit.time_window_end_2 }
  validate :time_window_end_2_after_time_window_start_2
  validate :time_window_start_2_after_time_window_end_1

  before_validation :nilify_priority
  validates :priority, numericality: { greater_than_or_equal_to: -4, less_than_or_equal_to: 4, message: I18n.t('activerecord.errors.models.visit.attributes.priority') }, allow_nil: true

  validate :quantities_validator

  include Consistency
  validate_consistency :tags, attr_consistency_method: ->(visit) { visit.destination.try :customer_id }

  before_save :update_tags, :create_orders, :update_quantities
  before_update :update_outdated
  after_save -> { @tag_ids_changed = false }

  include RefSanitizer

  include LocalizedAttr

  attr_localized :quantities

  include TypedAttribute
  typed_attr :custom_attributes

  amoeba do
    exclude_association :stop_visits
    exclude_association :orders

    customize(lambda { |_original, copy|
      def copy.update_tags; end

      def copy.create_orders; end

      def copy.update_outdated; end

      def copy.update_quantities; end
    })
  end

  # Custom validator for quantities. Mostly used by the destination model (:update, :create)
  def quantities_validator
    !quantities || quantities.values.each do |q|
      Float(q);
    end
  rescue StandardError => e
    self.errors.add :quantities, :not_float if e.is_a?(ArgumentError) || e.is_a?(TypeError)
  end

  def destroy
    # Do not use local collection stop_visits
    destination.customer.plannings.each do |planning|
      planning.visit_remove(self) if planning.visits_include?(self)
      planning.save! # To shift index
    end
    super
  end

  def changed?
    @tag_ids_changed || super
  end

  def outdated
    # Temporary disable lock version because several object_ids from the same route are loaded in main customer graph (in case of import)
    begin
      ActiveRecord::Base.lock_optimistically = false
      stop_visits.each { |stop|
        if !stop.route.outdated
          stop.route.outdated = true
          stop.route.save!
        end
      }
    ensure
      ActiveRecord::Base.lock_optimistically = true
    end

    # Previous solution:
    # # Do not call during a planning/route save processing
    # Route.transaction do
    #   # Function should be called outside update for planning/route
    #   # => Allow using different graph
    #   Route.where(id: stop_visits.map(&:route_id).uniq).each { |route|
    #     route.outdated = true
    #     route.save!
    #   }
    # end
  end


  # FIXME: Enum returns integer value instead of string key
  def attributes
    visit_attributes = super
    visit_attributes['force_position'] = self.force_position
    visit_attributes
  end

  def default_duration
    duration || destination.customer.visit_duration
  end

  def default_duration_time_with_seconds
    duration_time_with_seconds || destination.customer.visit_duration_time_with_seconds
  end

  def default_quantities
    @default_quantities ||= Hash[destination.customer.deliverable_units.collect{ |du|
      [du.id, quantities && quantities[du.id] ? quantities[du.id] : du.default_quantity]
    }]
    @default_quantities
  end

  def default_quantities?
    default_quantities && default_quantities.values.any?{ |q| q }
  end

  def quantities?
    quantities && quantities.values.any?{ |q| q }
  end

  def quantities_changed?
    !quantities.empty? ? quantities.any?{ |i, q| q != quantities_was[i] } : !quantities_was.empty?
  end

  def color
    @color ||= (tags | destination.tags).find(&:color).try(&:color)
  end

  def icon
    @icon ||= (tags | destination.tags).find(&:icon).try(&:icon)
  end

  def icon_size
    @icon_size ||= (tags | destination.tags).find(&:icon_size).try(&:icon_size)
  end

  def default_color
    color || Mapotempo::Application.config.destination_color_default
  end

  def default_icon
    icon || Mapotempo::Application.config.destination_icon_default
  end

  def default_icon_size
    nil
  end

  def priority_text
    if !priority || priority == 0
      I18n.t('visits.priority_level.medium')
    elsif priority > 0 && priority <= 4
      I18n.t('visits.priority_level.high')
    elsif priority < 0 && priority >= -4
      I18n.t('visits.priority_level.low')
    end
  end

  def update_tags_track(_tag)
    @tag_ids_changed = true
  end

  private

  def nilify_priority
    self.priority = nil if self.priority && (self.priority == 0 || self.priority == '0')
  end

  def update_outdated
    if @tag_ids_changed || time_window_start_1_changed? || time_window_end_1_changed? || time_window_start_2_changed? || time_window_end_2_changed? || quantities_changed? || duration_changed? || force_position_changed?
      outdated
    end
  end

  def tag_ids_changed?
    @tag_ids_changed
  end

  def update_tags
    if destination.customer && (@tag_ids_changed || new_record?)
      # Don't use local collection here, not set when save new record
      destination.customer.plannings.each do |planning|
        if !new_record? && planning.visits_include?(self)
          if planning.tag_operation == '_or'
            unless (planning.tags.to_a & (tags.to_a | destination.tags.to_a)).present?
              planning.visit_remove(self)
            end
          else
            if planning.tags.to_a & (tags.to_a | destination.tags.to_a) != planning.tags.to_a
              planning.visit_remove(self)
            end
          end
        elsif planning.tags_compatible?(tags.to_a | destination.tags.to_a)
          planning.visit_add(self)
        end
        planning.save! if !new_record?
      end
    end

    true
  end

  def create_orders
    if destination.customer && new_record?
      destination.customer.order_arrays.each{ |order_array|
        order_array.add_visit(self)
      }
    end
  end

  def update_quantities
    if quantities_changed? || quantities_operations_changed?
      quantities_operations.each{ |k, v|
        quantities[k] = -quantities[k] if v == 'empty' && quantities[k] && quantities[k] > 0
        quantities[k] = 0 if !quantities[k] && (v == 'fill' || v == 'empty')
      }
    end
  end

  def time_window_end_1_after_time_window_start_1
    if self.time_window_start_1.present? && self.time_window_end_1.present? && self.time_window_end_1 < self.time_window_start_1
      raise Exceptions::CloseAndOpenErrors.new(nil, id, nested_attr: :time_window_end_1, record: self)
    end
  rescue Exceptions::CloseAndOpenErrors
    self.errors.add(:time_window_end_1, :after, s: I18n.t('activerecord.attributes.visit.time_window_start_1').downcase)
  end

  def time_window_end_2_after_time_window_start_2
    if self.time_window_start_2.present? && self.time_window_end_2.present? && self.time_window_end_2 < self.time_window_start_2
      raise Exceptions::CloseAndOpenErrors.new(nil, id, nested_attr: :time_window_end_2, record: self)
    end
  rescue Exceptions::CloseAndOpenErrors
    self.errors.add(:time_window_end_2, :after, s: I18n.t('activerecord.attributes.visit.time_window_start_2').downcase)
  end

  def time_window_start_2_after_time_window_end_1
    if self.time_window_start_2.present? && self.time_window_end_1.present? && self.time_window_start_2 < self.time_window_end_1
      raise Exceptions::CloseAndOpenErrors.new(nil, id, nested_attr: :time_window_end_2, record: self)
    end
  rescue Exceptions::CloseAndOpenErrors
    self.errors.add(:time_window_start_2, :after, s: I18n.t('activerecord.attributes.visit.time_window_end_1').downcase)
  end
end
