module MobileHelper
  def detect_agent
    return :ios if controller.request.user_agent.match('iPhone OS')

    return :mobile if controller.request.user_agent.match('Mobile')

    :standard
  end
end
