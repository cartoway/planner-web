module MobileHelper
  def detect_agent
    return :ios if request.user_agent.match('iPhone OS')

    return :mobile if request.user_agent.match('Mobile')

    :standard
  end
end
