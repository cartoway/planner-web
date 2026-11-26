module MobileHelper
  MOBILE_NAV_APPS = %w[apple benav google waze].freeze
  MOBILE_NAV_DEFAULT = 'benav'.freeze

  def detect_agent
    return :standard if controller.request.user_agent.nil?

    ua = controller.request.user_agent
    # iPadOS 13+ may omit "iPad" and look like desktop Safari + Mobile.
    return :ios if ua.match(/iPhone|iPad/i) || (ua.match(/Macintosh/i) && ua.match(/Mobile/i))

    return :mobile if ua.match('Mobile')

    :standard
  end

  # Apple Maps — system default on iOS; used as href fallback when a deep link does not open.
  def mobile_nav_apple_url(lat, lng)
    lat_f, lng_f = nav_coords(lat, lng)
    "http://maps.apple.com/?daddr=#{lat_f},#{lng_f}"
  end

  # BeNav startGuidance deeplink (JSON-RPC command, Base64 in query).
  def mobile_nav_benav_url(lat, lng)
    lat_f, lng_f = nav_coords(lat, lng)
    command = {
      jsonrpc: '2.0',
      id: '1',
      method: 'startGuidance',
      params: {
        destination: {
          id: 'dest',
          lat: lat_f,
          lon: lng_f
        }
      }
    }
    "benav://?cmd=#{Base64.strict_encode64(command.to_json)}"
  end

  def mobile_nav_google_url(lat, lng)
    lat_f, lng_f = nav_coords(lat, lng)
    "comgooglemaps://?daddr=#{lat_f},#{lng_f}&directionsmode=driving"
  end

  def mobile_nav_waze_url(lat, lng)
    lat_f, lng_f = nav_coords(lat, lng)
    "waze://?ll=#{lat_f},#{lng_f}&navigate=yes"
  end

  def mobile_nav_android_url(lat, lng)
    lat_f, lng_f = nav_coords(lat, lng)
    "geo:#{lat_f},#{lng_f}?q=#{lat_f},#{lng_f}"
  end

  # Options for the mobile "Navigate" <a>: on iOS, deep-link from the header picker then fall back to Apple Maps.
  def mobile_nav_link_attrs(lat, lng, agent)
    base_class = 'col-xs-12 col-sm-6 btn btn-default no-toggle mr-2 pull-right'
    if agent == :ios
      {
        href: mobile_nav_apple_url(lat, lng),
        class: "#{base_class} mobile-nav-link",
        data: {
          nav_apple: mobile_nav_apple_url(lat, lng),
          nav_benav: mobile_nav_benav_url(lat, lng),
          nav_google: mobile_nav_google_url(lat, lng),
          nav_waze: mobile_nav_waze_url(lat, lng)
        }
      }
    else
      {
        href: mobile_nav_android_url(lat, lng),
        class: base_class
      }
    end
  end

  private

  # Normalize depot snapshot strings and stop floats the same way.
  def nav_coords(lat, lng)
    [Float(lat), Float(lng)]
  rescue ArgumentError, TypeError
    [lat.to_f, lng.to_f]
  end
end
