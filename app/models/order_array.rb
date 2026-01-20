# Copyright © Mapotempo, 2014-2016
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
class OrderArray < ApplicationRecord
  default_scope { order(:id) }

  belongs_to :customer
  has_many :orders, inverse_of: :order_array, autosave: true, dependent: :delete_all
  has_many :plannings, inverse_of: :order_array, dependent: :nullify
  enum length: {week: 7, week2: 14, month: 31}

  nilify_blanks
  auto_strip_attributes :name
  validates :customer, presence: true
  validates :name, presence: true
  validates :base_date, presence: true
  validates :length, presence: true

  before_save :update_orders

  def days
    @days = nil if base_date_changed? || length_changed?
    @days ||= !base_date ? 0 : week? ? 7 : week2? ? 14 : ((base_date >> 1) - base_date).numerator
  end

  def default_orders
    customer.destinations.each{ |destination|
      destination.visits.each{ |visit|
        add_visit(visit)
      }
    }
  end

  def visits_orders
    orders.joins(:products)
    orders.group_by(&:visit_id).values.sort_by{ |visit_orders|
      [visit_orders[0].visit.destination.name, visit_orders[0].visit.id]
    }.collect{ |visit_orders|
      visit_orders.sort_by(&:shift)
    }
  end

  def add_visit(visit)
    days.times{ |i|
      orders.build(shift: i, visit: visit)
    }
  end

  private

  def update_orders
    if base_date_changed? || length_changed?
      orders_by_shift_size = orders.group_by(&:shift).size
      if days > orders_by_shift_size
        (days - orders_by_shift_size).times{ |i|
          customer.destinations.each{ |destination|
            destination.visits.each{ |visit|
              orders.build(shift: orders_by_shift_size + i, visit: visit)
            }
          }
        }
      elsif days < orders_by_shift_size
        orders.select{ |o| o.shift + 1 > days }.each{ |o| orders.destroy(o) }
      end
    end
  end
end
