module RouteExportHelper
  # nil => no stops filter (export everything); Array => selected optional stop categories.
  # Prefer the value captured on the controller before streaming starts.
  def export_stop_categories
    if controller&.instance_variable_defined?(:@export_stop_categories)
      return controller.instance_variable_get(:@export_stop_categories)
    end
    return @export_stop_categories if instance_variable_defined?(:@export_stop_categories)

    request_params = controller&.params || (instance_variable_defined?(:@params) ? @params : nil)
    return nil unless request_params&.key?(:stops)

    Array(request_params[:stops]).flat_map { |value| value.to_s.split('|') }.reject(&:blank?)
  end

  def export_includes_stop_category?(category)
    categories = export_stop_categories
    categories.nil? || categories.include?(category)
  end

  def export_include_stop?(stop)
    type_allowed =
      case stop
      when StopVisit
        true
      when StopRest
        export_includes_stop_category?('rest')
      when StopStore
        export_includes_stop_category?('store')
      else
        false
      end
    return false unless type_allowed

    active_allowed = stop.active || stop.route.vehicle_usage_id.blank? || export_includes_stop_category?('inactive')
    out_of_route_allowed = stop.route.vehicle_usage_id.present? || export_includes_stop_category?('out-of-route')

    active_allowed && out_of_route_allowed
  end
end
