# Blocks all web crawlers from indexing the site
# Inspired by https://thoughtbot.com/blog/block-web-crawlers-with-rails
module Rack
  class XRobotsTag
    def initialize(app)
      @app = app
    end

    def call(env)
      status, headers, response = @app.call(env)

      headers["X-Robots-Tag"] = "none"

      [status, headers, response]
    end
  end
end
