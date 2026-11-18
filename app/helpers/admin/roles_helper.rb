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
module Admin::RolesHelper
  def role_icon(role)
    icon = role.icon.presence
    return content_tag(:span, "\u2014", class: 'text-muted role-list-icon__placeholder') if icon.blank?

    style = role.color.present? ? format('color: %s', role.color) : nil
    # fa-fw keeps a fixed glyph box so list rows stay vertically aligned.
    content_tag :i, '', class: format('fa fa-fw %s', icon), style: style, 'aria-hidden': true
  end

  def role_space_resource_label(sid)
    t("admin.roles.form.space_resources.#{sid}", default: sid.to_s.humanize)
  end

  def role_space_action_label(space_key, aid)
    t(
      "admin.roles.form.space_actions.#{space_key}.#{aid}",
      default: t("admin.roles.form.space_actions.common.#{aid}", default: aid.to_s.humanize)
    )
  end

  def role_operations_mobile_capability_label(key)
    t("admin.roles.operations_mobile.capabilities.#{key}", default: key.to_s.tr('.', ' ').humanize)
  end

  def role_transfer_items(ids)
    Array(ids).map { |id| { value: id, label: yield(id) } }
  end

  # Three-tier permission columns for v2 transfer_list (Active / Disabled / Hidden).
  # +items+ are arrays of { value:, label: } hashes; +hidden_name+ may be nil (no form field).
  def role_permission_three_tier_columns(active_name:, disabled_name:, hidden_name: nil,
                                         active_items: [], disabled_items: [], hidden_items: [])
    [
      {
        key: 'active',
        title: t('users.form.display_ui.operations_active'),
        icon_class: 'fa fa-check fa-fw',
        icon_style: 'color: green;',
        zone_class: 'active-zone',
        toggle_to: 'disabled',
        transfer_all_to: 'disabled',
        transfer_all_icon_class: 'fa fa-angle-double-right',
        input_name: active_name,
        items: active_items
      },
      {
        key: 'disabled',
        title: t('users.form.display_ui.operations_disabled'),
        icon_class: 'fa fa-ban fa-fw',
        icon_style: 'color: #856404;',
        zone_class: 'disabled-zone',
        toggle_to: 'hidden',
        transfer_all_to: 'hidden',
        transfer_all_icon_class: 'fa fa-angle-double-right',
        input_name: disabled_name,
        items: disabled_items
      },
      {
        key: 'hidden',
        title: t('users.form.display_ui.operations_hidden'),
        inactive: true,
        icon_class: 'fa fa-times fa-fw',
        icon_style: 'color: red;',
        zone_class: 'inactive-zone',
        toggle_to: 'active',
        transfer_all_to: 'active',
        transfer_all_icon_class: 'fa fa-angle-double-left',
        input_name: hidden_name,
        items: hidden_items
      }
    ]
  end
end
