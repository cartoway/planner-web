module MobileHelper
  def detect_agent
    return :standard if controller.request.user_agent.nil?

    return :ios if controller.request.user_agent.match('iPhone')

    return :mobile if controller.request.user_agent.match('Mobile')

    :standard
  end

  # Apple Maps — used as href (works without JS) and as BeNav fallback on iOS.
  def mobile_nav_fallback_url(lat, lng)
    "http://maps.apple.com/?daddr=#{lat},#{lng}"
  end

  # BeNav custom scheme (see BeNomad iOS deeplink doc). Adjust path/params if their format differs.
  def mobile_nav_benav_url(lat, lng)
    "benav://navigate?lat=#{lat}&lon=#{lng}"
  end

  def mobile_nav_android_url(lat, lng)
    "geo:#{lat},#{lng}?q=#{lat},#{lng}"
  end

  # Options for the mobile "Navigate" <a>: on iOS, try BeNav then fall back to Apple Maps.
  def mobile_nav_link_attrs(lat, lng, agent)
    base_class = 'col-xs-12 col-sm-6 btn btn-default no-toggle mr-2 pull-right'
    if agent == :ios
      {
        href: mobile_nav_fallback_url(lat, lng),
        class: "#{base_class} mobile-nav-link",
        data: { nav_primary: mobile_nav_benav_url(lat, lng) }
      }
    else
      {
        href: mobile_nav_android_url(lat, lng),
        class: base_class
      }
    end
  end
end
