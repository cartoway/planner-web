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

require "#{Rails.root}/lib/visit_quantities"

module VisitsHelper
  def visit_quantities(visit, vehicle, options = {})
    VisitQuantities.normalize(visit, vehicle, options)
  end

  def visit_force_position_options_for_select
    [
      [t('activerecord.attributes.visits.force_position.neutral'), :neutral],
      [t('activerecord.attributes.visits.force_position.always_first'), :always_first],
      [t('activerecord.attributes.visits.force_position.always_last'), :always_last],
      [t('activerecord.attributes.visits.force_position.never_first'), :never_first]
    ]
  end

  def visit_force_position_options_for_select_selected(visit)
    [t("activerecord.attributes.visits.force_position.#{visit.force_position}"), visit.force_position]
  end
end
