# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

class PlanningState < ApplicationRecord
  MAX_PER_GROUP = 5
  MAX_PINNED_PER_GROUP = 3

  CATEGORIES = %w[mass group individual].freeze

  TRIGGER_GROUPS = {
    'mass' => %w[
      optimize apply_zonings vehicle_usage_set import duplicate
      activate_stops
    ].freeze,
    'group' => %w[
      active optimize_route reverse_order automatic_insert
    ].freeze,
    'individual' => %w[
      move update_stop
    ].freeze
  }.freeze

  TRIGGER_TO_CATEGORY = TRIGGER_GROUPS.each_with_object({}) do |(category, triggers), hash|
    triggers.each { |trigger| hash[trigger] = category }
  end.freeze

  belongs_to :planning

  validates :captured_at, presence: true
  validates :trigger, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :payload, presence: true
  validates :statistics, presence: true
  validate :category_matches_trigger

  default_scope { order(pinned: :desc, captured_at: :desc) }

  scope :pinned_only, -> { where(pinned: true) }

  def self.category_for(trigger)
    TRIGGER_TO_CATEGORY[trigger.to_s] || 'individual'
  end

  def self.pinned_count_for(planning_id, category)
    unscoped.where(planning_id: planning_id, category: category, pinned: true).count
  end

  def self.prune_excess!(planning_id)
    CATEGORIES.each do |category|
      scope = unscoped.where(planning_id: planning_id, category: category)

      pinned_ids =
        scope.pinned_only
             .order(captured_at: :desc)
             .limit(MAX_PINNED_PER_GROUP)
             .pluck(:id)

      remaining_slots = MAX_PER_GROUP - pinned_ids.size
      unpinned_ids =
        if remaining_slots.positive?
          scope.where(pinned: false)
               .order(captured_at: :desc)
               .limit(remaining_slots)
               .pluck(:id)
        else
          []
        end

      ids_to_keep = pinned_ids + unpinned_ids
      next if ids_to_keep.empty?

      scope.where.not(id: ids_to_keep).delete_all
    end
  end

  private

  def category_matches_trigger
    return if trigger.blank? || category.blank?

    expected = self.class.category_for(trigger)
    return if category == expected

    errors.add(:category, "does not match trigger #{trigger}")
  end
end
