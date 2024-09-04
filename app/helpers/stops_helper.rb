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
module StopsHelper
  def stop_order_quantities(stop)
    stop.order.products.map(&:code).each_with_object({}){ |code, hash| hash.key?(code) ? hash[code] += 1 : hash[code] = 1 }
  end

  def stop_condensed_time_windows(stop)
    return if !stop.time_window_start_1 && !stop.time_window_end_1

    condensed_string = ""
    if stop.time_window_start_1_time
      day_number_start_1 = number_of_days(stop.time_window_start_1)
      condensed_string += stop.time_window_start_1_time
      condensed_string += "(+#{day_number_start_1})" if day_number_start_1
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_start_1')})" unless stop.time_window_end_1_time
    end
    condensed_string += '-' if stop.time_window_start_1_time && stop.time_window_end_1_time
    if stop.time_window_end_1_time
      day_number_end_1 = number_of_days(stop.time_window_end_1)
      condensed_string += stop.time_window_end_1_time
      condensed_string += "(+#{day_number_end_1})" if day_number_end_1
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_end_1')})" unless stop.time_window_start_1_time
    end
    return condensed_string if !stop.time_window_start_2 && !stop.time_window_end_2

    condensed_string += ' / '
    if stop.time_window_start_2_time
      day_number_start_2 = number_of_days(stop.time_window_start_2)
      condensed_string += stop.time_window_start_2_time
      condensed_string += "(+#{day_number_start_2})" if day_number_start_2
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_start_2')})" unless stop.time_window_end_2_time
    end
    condensed_string += '-' if stop.time_window_start_2_time && stop.time_window_end_2_time
    if stop.time_window_end_2_time
      day_number_end_2 = number_of_days(stop.time_window_end_2)
      condensed_string += stop.time_window_end_2_time
      condensed_string += "(+#{day_number_end_2})" if day_number_end_2
      condensed_string += " (#{I18n.t('plannings.edit.popup.time_window_end_2')})" unless stop.time_window_start_2_time
    end
    condensed_string
  end

  def custom_attribute_form_field(form, stop, custom_attribute)
    field_name = "stop[custom_attributes][#{custom_attribute.name}]"
    current_value = stop.custom_attributes_typed_hash[custom_attribute.name] || custom_attribute.typed_default_value
    case custom_attribute.object_type_before_type_cast
    when 0
      render partial: 'shared/check_box', locals: { form: form, name: field_name, checked: current_value, help: custom_attribute.description, label: custom_attribute.name, options: { label_col: 'd-none', help_label_class: 'd-none'} }
    when 1
      text_area_tag field_name, current_value, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control'
    when 2
      number_field_tag field_name, current_value, step: 1, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control', onkeypress: "return event.charCode >= 48 && event.charCode <= 57"
    when 3
      number_field_tag field_name, current_value, step: :any, help: custom_attribute.description, label: custom_attribute.name, class: 'form-control'
    when 4
      current_value = stop.custom_attributes_typed_hash[custom_attribute.name]
      select_tag field_name, options_for_select(custom_attribute.typed_default_value, current_value), {include_blank: true, help: custom_attribute.description, label: custom_attribute.name, class: "selectpicker", class: 'form-control' }
    end
  end
end
