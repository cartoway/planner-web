Rails.application.config.after_initialize do
  Rails.application.config.url_shortener = UrlShortenerService.new
end
