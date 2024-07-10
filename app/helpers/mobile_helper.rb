module MobileHelper
  def detect_agent
    return :standard if controller.request.user_agent.nil?

    return :ios if controller.request.user_agent.match('iPhone')

    return :mobile if controller.request.user_agent.match('Mobile')

    :standard
  end
end
