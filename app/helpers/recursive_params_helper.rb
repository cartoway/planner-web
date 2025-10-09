module RecursiveParamsHelper
  def permit_recursive(params)
    return params unless params.respond_to?(:each)

    params_hash = params.is_a?(ActionController::Parameters) ? params.to_unsafe_h : params
    params_hash.map do |key, value|
      if value.is_a?(Array) && value.none?{ |v| v.respond_to?(:each) }
        { key => [] }
      elsif value.is_a?(Array)
        { key => permit_recursive(value.first) }
      elsif value.is_a?(Hash) || value.is_a?(ActionController::Parameters)
        { key => permit_recursive(value) }
      else
        key
      end
    end
  end
  module_function :permit_recursive
end
