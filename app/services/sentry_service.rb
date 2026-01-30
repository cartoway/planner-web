class SentryService
  attr_accessor :current_user, :_request, :_params, :error, :payload

  def initialize(current_user, request, params, error, payload = {})
    @current_user = current_user
    @_request = request
    @_params = params
    @error = error
    @payload = payload
  end

  def register
    Sentry.set_user(user_context)
    Sentry.set_tags(tags_context)
    Sentry.set_extras(extra_context)
  end

  private

  def user_context
    return {} if @current_user.blank?

    {
      id: @current_user.id
    }
  end

  def tags_context
    {
      action: @_params[:action],
      controller: @_params[:controller],
      environment: Rails.env,
      error_class: @error.class.to_s,
      'planner.user_id': @current_user&.id,
      'planner.customer_id': @current_user&.customer_id,
      'planner.reseller_id': @current_user&.reseller_id || @current_user&.customer&.reseller_id,
      'planner.ref': @current_user&.ref,
      'planner.admin': @current_user&.admin?
    }
  end

  def extra_context
    extra = {
      params: @_params.to_enum.to_h.with_indifferent_access,
      url: @_request.try(:url),
      uuid: @_request.try(:uuid),
      ip: @_request.try(:ip),
      fullpath: @_request.try(:fullpath),
      error_message: @error.message,
    }

    @payload.each do |k, v|
      extra[k] = v.try(:as_json).try(:with_indifferent_access)
    end

    extra
  end
end
