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

module PlanningSpreadsheetHelper
  # Label for spreadsheet export columns (mirrors legacy plannings.js getDisplayName).
  def planning_spreadsheet_column_label(column, custom_columns = {})
    column = column.to_s
    match = column.match(/\A(.+)\[(.*)\]\z/)
    rematch = column.match(/\A([a-z]+(?:_[a-z]+)*)(\d+)\z/)
    if match
      base_key = match[1]
      suffix = "[#{match[2]}]"
    elsif rematch
      base_key = rematch[1]
      suffix = rematch[2]
    else
      base_key = column
      suffix = ''
    end
    label = t("plannings.export_file.#{base_key}", default: t("destinations.import_file.#{base_key}", default: base_key))
    label = "#{label}#{suffix}"
    custom = custom_columns[column] || custom_columns[column.to_sym]
    custom.present? ? "#{label} (#{custom})" : label
  end

  def planning_spreadsheet_column_lists(available_columns, settings)
    available = available_columns.map(&:to_s)
    export = Array(settings['export']).map(&:to_s) & available
    skip = Array(settings['skips']).map(&:to_s) & available
    available.each { |column| export << column unless export.include?(column) || skip.include?(column) }
    [export, skip]
  end
end
