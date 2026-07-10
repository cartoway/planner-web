# frozen_string_literal: true

module Lookbook
  module VisualRegression
    # Reads the latest Playwright snapshot comparison exported for the Lookbook UI.
    class Report
      MANIFEST_PATH = Rails.root.join('public/lookbook-visual-regression/manifest.json')
      PUBLIC_PREFIX = '/lookbook-visual-regression'

      Preview = Struct.new(
        :name, :path, :status, :expected_url, :actual_url, :diff_url, :lookbook_preview_url,
        keyword_init: true
      )

      attr_reader :generated_at, :status, :passed_count, :failed_count, :previews

      def self.load
        return nil unless MANIFEST_PATH.exist?

        new(JSON.parse(MANIFEST_PATH.read))
      end

      def self.available?
        MANIFEST_PATH.exist?
      end

      def initialize(data)
        @generated_at = Time.zone.parse(data['generated_at'].to_s)
        @status = data['status'].to_s
        @passed_count = data['passed_count'].to_i
        @failed_count = data['failed_count'].to_i
        @previews = Array(data['previews']).map do |row|
          Preview.new(
            name: row['name'],
            path: row['path'],
            status: row['status'],
            expected_url: row['expected_url'],
            actual_url: row['actual_url'],
            diff_url: row['diff_url'],
            lookbook_preview_url: row['lookbook_preview_url']
          )
        end
      rescue ArgumentError, TypeError
        nil
      end

      def passed?
        status == 'passed'
      end

      def failed_previews
        previews.select { |preview| preview.status == 'failed' }
      end
    end
  end
end
