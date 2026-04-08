require 'timeout'

class PerRouteTimeout
  DEFAULT_TIMEOUTS = {
    %r{^/api/} => 15, # default API
    %r{^/} => 60, # API 100
  }.freeze

  def initialize(app)
    @app = app
  end

  def call(env)
    path = env['PATH_INFO']
    timeout = resolved_timeouts.find { |pattern, _| pattern.match?(path) }&.last || default_timeout

    Timeout.timeout(timeout) { @app.call(env) }
  rescue Timeout::Error
    [504, { 'Content-Type' => 'text/plain' }, ['Gateway Timeout']]
  end

  private

  def resolved_timeouts
    configured_timeouts = Rails.configuration.x.per_route_timeouts || {}
    # Priority to the configured timeouts
    configured_timeouts.merge(DEFAULT_TIMEOUTS) { |_key, configured, _default| configured }
  end

  def default_timeout
    Rails.configuration.x.per_route_default_timeout || 30
  end
end
