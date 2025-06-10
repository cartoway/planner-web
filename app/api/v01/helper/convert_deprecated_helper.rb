module ConvertDeprecatedHelper
  extend Grape::API::Helpers

  def convert_deprecated_quantities(hash, deliverable_units)
    hash[:quantities] = [] if hash[:quantities].blank?

    if hash[:quantity] && deliverable_units.size > 0
      quantity = CoerceFloatString.parse(hash[:quantity])
      hash[:quantities] << {
        deliverable_unit_id: deliverable_units[0].id,
        quantity < 0 ? :pickup : :delivery => quantity.abs
      }
      hash.delete(:quantity)
    end

    if hash[:quantity1_1] && deliverable_units.size > 0
      quantity = CoerceFloatString.parse(hash[:quantity1_1])
      hash[:quantities] << {
        deliverable_unit_id: deliverable_units[0].id,
        quantity < 0 ? :pickup : :delivery => quantity.abs
      }
    end
    if hash[:quantity1_2] && deliverable_units.size > 1
      quantity = CoerceFloatString.parse(hash[:quantity1_2])
      hash[:quantities] << {
        deliverable_unit_id: deliverable_units[0].id,
        quantity < 0 ? :pickup : :delivery => quantity.abs
      }
    end

    return if hash[:quantities].is_a?(Hash)

    # Deals with deprecated quantity
    hash[:quantities].map!{ |q|
      next if q.blank?
      next q unless q[:quantity]

      quantity = CoerceFloatString.parse(q[:quantity])
      {
        deliverable_unit_label: q[:deliverable_unit_label],
        deliverable_unit_id: q[:deliverable_unit_id],
        quantity < 0 ? :pickup : :delivery => quantity.abs
      }.compact
    }.compact!
  end

  def convert_timewindows(hash)
    #Deals with deprecated schedule params
    hash[:time_window_start_1] ||= hash.delete(:open1) if hash[:open1]
    hash[:time_window_end_1] ||= hash.delete(:close1) if hash[:close1]
    hash[:time_window_start_2] ||= hash.delete(:open2) if hash[:open2]
    hash[:time_window_end_2] ||= hash.delete(:close2) if hash[:close2]
  end
end
