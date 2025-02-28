class UrlShortenerService
  def initialize
    @base_url = ENV['URL_SHORTENER']&.chomp('/')
  end

  def shorten(url)
    return url if @base_url.blank?

    return nil if url.nil? || url.size >= 1024

    response = RestClient.get(
      "#{@base_url}/shorten",
      params: { url: url }
    )
    response.body
  end

  def unshorten(short_code)
    return url if @base_url.blank?

    return nil if short_code.nil?

    response = RestClient.get("#{@base_url}/#{short_code}")
    response.headers[:location]
  end

  def generate_qr_code(url)
    return url if @base_url.blank?

    return nil if url.nil? || url.size >= 1024

    response = RestClient.get(
      "#{@base_url}/qrcode.svg",
      params: { url: url }
    )
    response.body if response.headers[:content_type] == 'image/svg+xml'
  end
end
