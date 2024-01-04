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
require 'font_awesome'

class DeliverableUnit < ApplicationRecord
  ICON_SIZE = %w(small medium large).freeze
  ICON_DEFAULT = 'fa-archive'.freeze

  default_scope { order(:label) }

  belongs_to :customer

  nilify_blanks before: :validation
  auto_strip_attributes :label
  validates :default_quantity, numericality: true, allow_nil: true
  validates :default_capacity, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :optimization_overload_multiplier, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  validates :ref, uniqueness: { scope: :customer_id, case_sensitive: true }, allow_nil: true, allow_blank: true

  validates_inclusion_of :icon, in: FontAwesome::ICONS_TABLE, allow_nil: true, message: ->(*_) { I18n.t('activerecord.errors.models.store.icon_unknown') }

  before_save :outdated

  include LocalizedAttr
  include RefSanitizer

  attr_localized :default_quantity, :default_capacity, :optimization_overload_multiplier

  def default_optimization_overload_multiplier
    optimization_overload_multiplier || Mapotempo::Application.config.optimize_overload_multiplier
  end

  def default_icon
    icon || ICON_DEFAULT
  end

  private

  def outdated
    if default_quantity_changed? || default_capacity_changed?
      customer.deliverable_units_updated = true
    end
  end
end
