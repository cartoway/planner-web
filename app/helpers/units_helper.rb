# Copyright © Mapotempo, 2018
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
require 'distance_units'

module UnitsHelper
  def distance_in_user_unit(meters, unit)
    unit == 'mi' ? DistanceUnits.meters_to_miles(meters).round(2) : DistanceUnits.meters_to_kms(meters).round(2) if meters
  end

  def currencies_table
    User.prefered_currencies.keys.map{ |key|
      ["#{t("all.unit.currency.#{key}")} - #{t("all.unit.currency_symbol.#{key}")}", key]
    }
  end
end
