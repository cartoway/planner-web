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
module PreferencesAuthorization
  extend ActiveSupport::Concern

  private

  def deny_unless_operation_usable!(zone, segment_id)
    return if current_user.operation_segment_usable?(zone, segment_id)

    refuse_display_ui!
  end

  def deny_unless_form_visible!(resource)
    return if current_user.form_visible?(resource)

    refuse_display_ui!
  end

  def deny_unless_form_update!(resource)
    return if current_user.form_update?(resource)

    refuse_display_ui!
  end

  def deny_unless_form_create!(resource)
    return if current_user.form_create?(resource)

    refuse_display_ui!
  end

  def refuse_display_ui!
    respond_to do |format|
      format.html { head :forbidden }
      format.js { head :forbidden }
      format.json { head :forbidden }
      format.any { head :forbidden }
    end
  end
end
