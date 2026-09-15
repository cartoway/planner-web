# Short-lived tokens for api-web iframes so the long-lived user api_key stays off the URL.
class ApiWebEmbedToken
  PURPOSE = :api_web_embed
  DEFAULT_TTL = 1.hour
  MAX_TTL = 24.hours
  MIN_TTL = 60

  def self.issue!(user, expires_in: DEFAULT_TTL, origin: nil)
    ttl = expires_in.to_i.clamp(MIN_TTL, MAX_TTL.to_i)
    exp = Time.now.to_i + ttl
    origin = sanitize_origin(origin)
    token = verifier.generate({ 'uid' => user.id, 'exp' => exp, 'origin' => origin })
    { token: token, expires_at: Time.at(exp).utc, origin: origin }
  end

  def self.verify(token)
    return if token.blank?

    payload = verifier.verify(token)
    return if payload['exp'].to_i < Time.now.to_i

    user = User.find_by(id: payload['uid'])
    return unless user

    [user, payload['origin']]
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    nil
  end

  def self.sanitize_origin(origin)
    return if origin.blank?

    uri = URI.parse(origin.to_s.strip)
    return unless uri.is_a?(URI::HTTP) && uri.host.present? && uri.userinfo.nil?

    port = uri.port && uri.port != uri.default_port ? ":#{uri.port}" : ''
    "#{uri.scheme}://#{uri.host}#{port}"
  rescue URI::InvalidURIError
    nil
  end

  def self.verifier
    Rails.application.message_verifier(PURPOSE)
  end
end
