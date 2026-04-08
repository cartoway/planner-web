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

module Admin::UsersHelper
  include Admin::RolesHelper

  # Role icon (same styling as roles index) with role name as native tooltip.
  def admin_user_role_display(user)
    role = user.role
    return content_tag(:span, "\u2014", class: 'text-muted') if role.blank?

    content_tag(:span, role_icon(role), title: role.name, class: 'admin-user-role-icon')
  end
end
