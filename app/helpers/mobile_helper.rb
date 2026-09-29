module MobileHelper
  def detect_agent
    return :standard if controller.request.user_agent.nil?

    return :ios if controller.request.user_agent.match('iPhone')

    return :mobile if controller.request.user_agent.match('Mobile')

    :standard
  end

  # href is opened when Benav is not installed. benav is nil outside iOS.
  def mobile_navigation_links(agent, lat, lng)
    if agent == :ios
      ["http://maps.apple.com/?daddr=#{lat},#{lng}", benav_guidance_url(lat, lng)]
    else
      ["geo:#{lat},#{lng}?q=#{lat},#{lng}", nil]
    end
  end

  def benav_guidance_url(lat, lng)
    command = {
      jsonrpc: '2.0',
      id: '1',
      method: 'startGuidance',
      params: {
        destination: {
          id: 'dest',
          lat: lat.to_f,
          lon: lng.to_f
        }
      }
    }
    "benav://?cmd=#{Base64.strict_encode64(command.to_json)}"
  end
end
