# Copyright © Cartoway, 2025
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

module DecimalAttr
  extend ActiveSupport::Concern

  class_methods do
    def decimal_attr(*names, decimals: 2)
      names.each do |name|
        before_save "format_#{name}_decimal".to_sym

        define_method("format_#{name}_decimal") do
          value = send(name)
          if value.present?
            multiplier = 10 ** decimals
            formatted_value = (value * multiplier).round / multiplier.to_f
            send("#{name}=", formatted_value)
          end
        end
      end
    end
  end
end
