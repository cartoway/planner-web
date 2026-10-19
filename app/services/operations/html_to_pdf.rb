# frozen_string_literal: true

module Operations
  # HTML (print CSS) → PDF via headless Chromium (Ferrum).
  class HtmlToPdf
    class Unavailable < StandardError; end

    def self.call(html)
      new.call(html)
    end

    def self.available?
      path = chromium_path
      path.present? && File.executable?(path)
    end

    def self.chromium_path
      ENV['CHROMIUM_PATH'].presence ||
        %w[/usr/bin/chromium-browser /usr/bin/chromium /usr/bin/google-chrome].find { |path| File.executable?(path) }
    end

    def call(html)
      raise Unavailable, 'Chromium is not available for PDF export' unless self.class.available?

      require 'ferrum'
      browser = Ferrum::Browser.new(
        browser_path: self.class.chromium_path,
        headless: true,
        timeout: 30,
        browser_options: {
          'no-sandbox': nil,
          'disable-gpu': nil,
          'disable-dev-shm-usage': nil,
          'hide-scrollbars': nil
        }
      )
      browser.page.content = html
      browser.network.wait_for_idle(duration: 0.2)
      browser.pdf(
        encoding: :binary,
        print_background: true,
        prefer_css_page_size: true,
        margin_top: 0.4,
        margin_bottom: 0.4,
        margin_left: 0.4,
        margin_right: 0.4
      )
    ensure
      browser&.quit
    end
  end
end
