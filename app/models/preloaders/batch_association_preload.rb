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
module Preloaders
  # Generic per-batch association preload using ActiveRecord::Associations::Preloader.
  # Prefer this over relation.preload + find_each / in_batches when scopes are poorly
  # optimized with Rails 6.
  #
  # Domain-specific trees live in sibling modules (e.g. Preloaders::PlanningBatchPreload::ASSOCIATIONS).
  module BatchAssociationPreload
    def self.preload!(records, associations)
      return if records.blank?

      ActiveRecord::Associations::Preloader.new.preload(records, associations)
    end

    def self.each_batch(relation, associations:, batch_size: 30)
      # find_in_batches always uses primary-key order; a scoped ORDER is ignored and Rails
      # logs a warning. Drop it explicitly — batch order of parents does not affect
      # association order (e.g. stops still follow the route's has_many :stops scope).
      relation = relation.unscope(:order)
      relation.find_in_batches(batch_size: batch_size) do |batch|
        preload!(batch, associations)
        yield batch
      end
    end
  end
end
