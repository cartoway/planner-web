require 'cgi'

module LinkBack
  extend ActiveSupport::Concern

  included do
    after_action :save_link_back, only: [:new, :edit]
  end

  private

  def save_link_back
    # session[:previous_url] is a Rails built-in variable to save last url.
    if request.format == Mime[:html]
      referer_uri = request.referer ? URI.parse(request.referer) : nil
      referer_params = referer_uri && referer_uri.query ? CGI.parse(referer_uri.query) : nil
      referer_fragment = referer_uri && referer_uri.fragment
      if referer_uri && params['back']
        # FIXME: The controller is fired twice and cannot link_back to its referer
        unless session[:link_back]&.include?("#")
          session[:link_back] = referer_uri.path
          session[:link_back] += '#' + referer_fragment if referer_fragment
        end
      elsif !(referer_uri && referer_params && referer_params['back'])
        session.delete(:link_back)
      end
    end
  end

  def link_back
    session.delete(:link_back)
  end
end
