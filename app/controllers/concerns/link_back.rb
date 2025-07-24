require 'cgi'

module LinkBack
  extend ActiveSupport::Concern

  included do
    after_action :save_link_back, only: [:new, :edit]
  end

  private

  def save_link_back
    return unless request.get? && request.format.html?
    return unless request.headers['Turbolinks-Referrer']

    # URI fragments #123 are not part of the referer URI
    # TODO: It might be interesting to link back to it
    if request.format == Mime[:html]
      referer_uri = URI.parse(request.headers['Turbolinks-Referrer'])
      referer_params = referer_uri && referer_uri.query ? CGI.parse(referer_uri.query) : nil
      if referer_uri && params['back']
        session[:link_back] = referer_uri.path
      elsif referer_uri && referer_params && referer_params['back']
        # Clear link_back
        session.delete(:link_back)
      end
    end
  end

  def link_back
    session.delete(:link_back)
  end
end
