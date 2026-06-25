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

# Validates optional map icon sizes against MapIconSize::SIZES.
module ValidatesIconSize
  extend ActiveSupport::Concern

  class_methods do
    def validates_map_icon_sizes(*attributes)
      attributes.each do |attribute|
        validates attribute, inclusion: {
          in: MapIconSize::SIZES,
          allow_nil: true,
          message: ->(*) { I18n.t("activerecord.errors.models.#{model_name.i18n_key}.icon_size_invalid") }
        }
      end
    end

    def map_icon_size_attributes
      [:icon_size]
    end
  end

  included do
    validates_map_icon_sizes(*map_icon_size_attributes)
  end
end
