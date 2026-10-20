# frozen_string_literal: true

require 'open3'

module Operations
  # HTML (print CSS) → PDF via WeasyPrint CLI — no browser process.
  class HtmlToPdf
    class Unavailable < StandardError; end

    def self.call(html, media_type: 'screen')
      new(media_type: media_type).call(html)
    end

    def self.available?
      path = weasyprint_path
      path.present? && File.executable?(path)
    end

    def self.weasyprint_path
      ENV['WEASYPRINT_PATH'].presence ||
        %w[/usr/bin/weasyprint].find { |path| File.executable?(path) } ||
        (bin = `command -v weasyprint 2>/dev/null`.to_s.strip).presence
    end

    def initialize(media_type: 'screen')
      @media_type = media_type
    end

    def call(html)
      raise Unavailable, 'WeasyPrint is not available for PDF export' unless self.class.available?

      # screen media matches the web delivery-note layout (flex); print media uses floats for browser print.
      pdf, status = Open3.capture2(
        self.class.weasyprint_path,
        '--media-type', @media_type,
        '--base-url', "file://#{Rails.root}/",
        '-', '-',
        stdin_data: html
      )
      raise Unavailable, "WeasyPrint failed (exit #{status.exitstatus})" unless status.success?

      pdf
    end
  end
end
