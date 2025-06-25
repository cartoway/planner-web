# Copyright © Mapotempo, 2013-2017
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
class Stop < ApplicationRecord
  default_scope { order(:index) }

  belongs_to :route, touch: true
  belongs_to :visit, optional: true # TODO: Remove optional
  belongs_to :store, optional: true

  nilify_blanks

  include LocalizedAttr
  attr_localized :loads

  include QuantityAttr
  quantity_attr :loads

  include TimeAttr
  attribute :time, ScheduleType.new
  time_attr :time

  include TypedAttribute
  typed_attr :custom_attributes

  validates :route, presence: true

  scope :only_stop_visits, -> { where(type: StopVisit.name) }
  scope :only_stop_stores, -> { where(type: StopStore.name) }
  scope :only_active_stop_visits, -> { only_stop_visits.where(active: true) }
  scope :includes_destinations, -> { includes(visit: [:tags, destination: [:visits, :tags, {customer: :deliverable_units}]]) }
  scope :includes_relations, -> { includes(visit: [:relation_currents, :relation_successors])}

  before_save :outdate_route

  amoeba do
    enable
  end

  # Return best fit time window, and late (positive) time or waiting time (negative).
  def best_open_close(time)
    [[time_window_start_1, time_window_end_1], [time_window_start_2, time_window_end_2]].select{ |open, close|
      open || close
    }.collect{ |open, close|
      [open, close, eval_open_close(open, close, time)]
    }.min_by{ |_open, _close, eval|
      eval.abs
    }
  end

  def number(inactive_stop)
    if self.active && self.route.vehicle_usage_id
      self.index - inactive_stop
    else
      nil
    end
  end

  def default_color
    (self.visit && visit.color) || route.default_color
  end

  def outdate_route
    if active_changed? && !new_record?
      route.outdated = true if route
    end
  end

  def import_attributes
    self.attributes.except('lock_version')
  end

  private

  def eval_open_close(open, close, time)
    if open && time < open
      time - open # Negative
    elsif close && time > close
      soft_upper_bound = self.route.planning.customer.optimization_stop_soft_upper_bound || Planner::Application.config.optimize_stop_soft_upper_bound
      if soft_upper_bound > 0
        (time - close) * soft_upper_bound # Positive
      else
        2**31 # Strict
      end
    else
      0
    end
  end

end
