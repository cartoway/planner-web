require 'test_helper'

class PerRouteTimeoutTest < ActiveSupport::TestCase
  def setup
    super
    @original_timeouts = Rails.configuration.x.per_route_timeouts
    @original_default_timeout = Rails.configuration.x.per_route_default_timeout
  end

  def teardown
    Rails.configuration.x.per_route_timeouts = @original_timeouts
    Rails.configuration.x.per_route_default_timeout = @original_default_timeout
    super
  end

  test 'uses default api timeout' do
    middleware = build_middleware do
      sleep 0.05
      [200, {}, ['ok']]
    end

    response = middleware.call('PATH_INFO' => '/api/0.1/jobs/123')

    assert_equal 200, response[0]
  end

  test 'uses configured timeout for custom route' do
    Rails.configuration.x.per_route_timeouts = {
      %r{^/custom/slow} => 0.01
    }

    middleware = build_middleware do
      sleep 0.05
      [200, {}, ['ok']]
    end

    response = middleware.call('PATH_INFO' => '/custom/slow/export')

    assert_equal 504, response[0]
    assert_equal ['Gateway Timeout'], response[2]
  end

  test 'uses configured timeout override for api route' do
    Rails.configuration.x.per_route_timeouts = {
      %r{^/api/} => 0.01
    }

    middleware = build_middleware do
      sleep 0.05
      [200, {}, ['ok']]
    end

    response = middleware.call('PATH_INFO' => '/api/0.1/plannings')

    assert_equal 504, response[0]
  end

  test 'respects configured rules order' do
    Rails.configuration.x.per_route_timeouts = {
      %r{^/api/} => 0.05,
      %r{^/api/0\.1/} => 0.01
    }

    middleware = build_middleware do
      sleep 0.02
      [200, {}, ['ok']]
    end

    response = middleware.call('PATH_INFO' => '/api/0.1/jobs/123')

    assert_equal 200, response[0]
  end

  private

  def build_middleware(&block)
    app = lambda { |_env| block.call }
    PerRouteTimeout.new(app)
  end
end
