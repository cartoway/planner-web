class UrlShortenerService
  def initialize
    @base_url = ENV['URL_SHORTENER']&.chomp('/')
    @available = available?
  end

  def shorten(url)
    return url unless @available

    return nil if url.nil? || url.size >= 1024

    response = RestClient.get(
      "#{@base_url}/shorten",
      params: { url: url }
    )
    response.body
  end

  def unshorten(short_code)
    return nil if !@available || short_code.nil?

    response = RestClient.get("#{@base_url}/#{short_code}")
    response.headers[:location]
  end

  def generate_qr_code(url)
    return nil if !@available || url.nil? || url.size >= 1024

    response = RestClient.get(
      "#{@base_url}/qrcode.svg",
      params: { url: url }
    )
    response.body if response.headers[:content_type] == 'image/svg+xml'
  end

  private

  def available?
    return false if @base_url.blank?

    begin
      RestClient.get("#{@base_url}/").code == 204
    rescue RestClient::Exception, SocketError => e
      Rails.logger.warn("URL Shortener service unavailable: #{e.message}")
      false
    end
  end
end
