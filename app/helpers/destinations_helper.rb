# Copyright © Mapotempo, 2013-2014
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
module DestinationsHelper
  def csv_column_titles(customer)
    custom_columns = customer.advanced_options&.dig('import', 'destinations', 'spreadsheetColumnsDef')
    columns(customer).map{ |c|
      if custom_columns&.key?(c.to_s)
        custom_columns[c.to_s]
      elsif (m = m = /^(.+)\[(.*)\]$/.match(c))
        I18n.t('destinations.import_file.' + m[1]) + "[#{m[2]}]"
      elsif (m = /^([a-z]+(?:_[a-z]+)*)(\d+)$/.match(c))
        deliverable_unit = customer.deliverable_units.where(id: m[2].to_i).first
        I18n.t("destinations.import_file.#{m[1]}") + (deliverable_unit.label ? "[#{deliverable_unit.label}]" : "#{deliverable_unit.id}")
      else
        I18n.t('destinations.import_file.' + c.to_s)
      end
    }
  end

  def columns_destination(customer)
    dest_columns = %i[ref name street detail postalcode city]
    dest_columns << :state if customer.with_state?
    dest_columns += %i[country lat lng geocoding_accuracy geocoding_level geocoding_result comment phone_number tags]

    dest_columns
  end

  def columns_visit(customer)
    visit_columns = %i[ref_visit duration time_window_start_1 time_window_end_1 time_window_start_2 time_window_end_2]
    visit_columns += %i[priority tags_visit]
    unless @customer.enable_orders
      customer.deliverable_units.each{ |du|
        visit_columns += ["quantity#{du.id}".to_sym, "quantity_operation#{du.id}".to_sym]
      }
    end
    visit_columns += @customer.custom_attributes.select(&:visit?).map{ |ca| "custom_attributes_visit[#{ca.name}]" }
    visit_columns
  end

  def columns(customer)
    total_columns = columns_destination(customer)
    total_columns << :without_visit
    total_columns += columns_visit(customer)
  end
end
