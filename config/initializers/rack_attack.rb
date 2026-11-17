# frozen_string_literal: true

# Copyright © Cartoway, 2026
#
# This file is part of Cartoway Planner.
#
# Cartoway Planner is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Cartoway Planner is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Cartoway Planner. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#

class Rack::Attack
  cfg = RackAttackConfig.load

  throttle('driver/token', **RackAttackConfig.limits_for(cfg, 'driver_token')) do |req|
    next unless req.path.start_with?('/api/0.1/driver')

    auth = req.get_header('HTTP_AUTHORIZATION').to_s
    token = auth[/\ABearer\s+(\S+)\z/i, 1]
    next if token.blank?

    Digest::SHA256.hexdigest(token)
  end

  throttle('driver/public/ip', **RackAttackConfig.limits_for(cfg, 'driver_public_ip')) do |req|
    req.ip if req.post? && req.path.sub(/\.\w+\z/, '') == '/api/0.1/driver/account/session'
  end

  throttle('driver/session/ip', **RackAttackConfig.limits_for(cfg, 'driver_session_ip')) do |req|
    req.ip if req.post? && req.path.sub(/\.\w+\z/, '') == '/api/0.1/driver/account/session'
  end

  throttle('driver/session/email', **RackAttackConfig.limits_for(cfg, 'driver_session_email')) do |req|
    next unless req.post? && req.path.sub(/\.\w+\z/, '') == '/api/0.1/driver/account/session'

    body = req.body.read
    req.body.rewind
    email = JSON.parse(body)['email'].to_s.strip.downcase
    email.presence
  rescue JSON::ParserError, TypeError
    nil
  end

  self.throttled_responder = lambda do |_request|
    body = { message: 'Too many requests', status: 429, code: 'rate_limited' }.to_json
    [429, { 'Content-Type' => 'application/json' }, [body]]
  end
end

Rack::Attack.cache.store = ActiveSupport::Cache::MemoryStore.new if Rails.env.test?
