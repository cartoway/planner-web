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

module WorkspacesHelper
  # Enter a membership: Activate (same account/host) vs Handoff (reseller scope or other host).
  def workspace_enter_path(membership, reseller_scope:, same_host:)
    if reseller_scope || !same_host
      handoff_workspace_path(user_id: membership.id)
    else
      switch_workspace_path(user_id: membership.id)
    end
  end

  # Preserve list order (already sorted by customer name, then email).
  def workspace_chip_customer_groups(web_list)
    web_list.group_by(&:customer_id).map { |_id, memberships| [memberships.first.customer, memberships] }
  end

  def workspace_chip_item_icon(membership, same_host:, reseller_scope:)
    parts = []
    parts << if membership.id == current_user.id
               tag.i(class: 'fa fa-check fa-fw text-success')
             elsif !same_host
               tag.i(class: 'fa fa-external-link fa-fw')
             else
               tag.i(class: 'fa fa-fw')
             end
    if membership.role&.icon.present?
      style = membership.role.color.present? ? "color: #{membership.role.color}" : nil
      parts << tag.i(class: "fa fa-fw #{membership.role.icon}", style: style)
    end
    safe_join(parts)
  end

  def workspace_chip_user_label(membership)
    membership.email.presence || membership.role&.name.presence || "##{membership.id}"
  end

  def workspace_chip_item_label(membership, label:, same_host:, reseller_scope:)
    if !same_host && !reseller_scope
      t('workspaces.chip.open_on_host', host: membership.customer.reseller.host, name: label)
    else
      label
    end
  end
end
