# Copyright © Mapotempo, 2014-2015
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
require 'font_awesome'

class Store < Location
  ICON_SIZE = %w(small medium large).freeze

  default_scope { order(:id) }

  has_many :vehicle_usage_set_starts, class_name: 'VehicleUsageSet', inverse_of: :store_start, foreign_key: 'store_start_id'
  has_many :vehicle_usage_set_stops, class_name: 'VehicleUsageSet', inverse_of: :store_stop, foreign_key: 'store_stop_id'
  has_many :vehicle_usage_set_rests, class_name: 'VehicleUsageSet', inverse_of: :store_rest, foreign_key: 'store_rest_id', dependent: :nullify
  has_many :vehicle_usage_starts, class_name: 'VehicleUsage', inverse_of: :store_start, foreign_key: 'store_start_id', dependent: :nullify
  has_many :vehicle_usage_stops, class_name: 'VehicleUsage', inverse_of: :store_stop, foreign_key: 'store_stop_id', dependent: :nullify
  has_many :vehicle_usage_rests, class_name: 'VehicleUsage', inverse_of: :store_rest, foreign_key: 'store_rest_id', dependent: :nullify

  auto_strip_attributes :name, :street, :postalcode, :city
  validates_inclusion_of :icon, in: FontAwesome::ICONS_TABLE, allow_nil: true, message: ->(*_) { I18n.t('activerecord.errors.models.store.icon_unknown') }
  validates :icon_size, inclusion: { in: Store::ICON_SIZE, allow_nil: true, message: ->(*_) { I18n.t('activerecord.errors.models.store.icon_size_invalid') } }

  before_destroy :destroy_vehicle_store

  include RefSanitizer

  amoeba do
    exclude_association :vehicle_usage_set_starts
    exclude_association :vehicle_usage_set_stops
    exclude_association :vehicle_usage_set_rests
    exclude_association :vehicle_usage_starts
    exclude_association :vehicle_usage_stops
    exclude_association :vehicle_usage_rests

    customize(lambda { |_original, copy|
      def copy.destroy_vehicle_store; end
    })
  end

  include LocalizedAttr

  attr_localized :lat, :lng, :geocoding_accuracy

  def destroy
    outdated # Too late to do this in before_destroy callback, children already destroyed
    super
  end

  def default_color
    color || Mapotempo::Application.config.store_color_default
  end

  def default_icon
    icon || Mapotempo::Application.config.store_icon_default
  end

  def default_icon_size
    icon_size || Mapotempo::Application.config.store_icon_size_default
  end

  private

  def outdated
    Route.transaction do
      routes_usage_set = vehicle_usage_set_starts.collect{ |vehicle_usage_set_start|
        vehicle_usage_set_start.vehicle_usages.select{ |vehicle_usage| !vehicle_usage.store_start }.collect(&:routes)
      } + vehicle_usage_set_stops.collect{ |vehicle_usage_set_stop|
        vehicle_usage_set_stop.vehicle_usages.select{ |vehicle_usage| !vehicle_usage.store_stop }.collect(&:routes)
      } + vehicle_usage_set_rests.collect{ |vehicle_usage_set_rest|
        vehicle_usage_set_rest.vehicle_usages.select{ |vehicle_usage| !vehicle_usage.store_rest }.collect(&:routes)
      }

      routes_usage = (vehicle_usage_starts + vehicle_usage_stops + vehicle_usage_rests).collect(&:routes)

      (routes_usage_set + routes_usage).flatten.uniq.each{ |route|
        route.outdated = true
        route.save!
      }
    end
  end

  def destroy_vehicle_store
    default = customer.stores.find{ |store| store != self && !store.destroyed? }
    if default
      (vehicle_usage_set_starts + vehicle_usage_set_stops + vehicle_usage_set_rests).uniq.each{ |vehicle_usage_set|
        vehicle_usage_set.store_start = default if vehicle_usage_set.store_start == self
        vehicle_usage_set.store_stop = default if vehicle_usage_set.store_stop == self
        vehicle_usage_set.store_rest = default if vehicle_usage_set.store_rest == self
        vehicle_usage_set.save!
      }

      (vehicle_usage_starts + vehicle_usage_stops + vehicle_usage_rests).uniq.each{ |vehicle_usage|
        vehicle_usage.store_start = default if vehicle_usage.store_start == self
        vehicle_usage.store_stop = default if vehicle_usage.store_stop == self
        vehicle_usage.store_rest = default if vehicle_usage.store_rest == self
        vehicle_usage.save!
      }
      true
    else
      errors.add(:base, I18n.t('activerecord.errors.models.store.at_least_one'))
      false
    end
  end
end
