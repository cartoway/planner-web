# frozen_string_literal: true

module Lookbook
  module VisualRegression
    # Promotes the latest Playwright actual PNG to the committed *-linux.png baseline.
    class AcceptSnapshot
      Error = Class.new(StandardError)

      SNAPSHOTS_DIR = Rails.root.join('visual-regression/tests/lookbook.vrt.spec.ts-snapshots')
      EXPORT_SCRIPT = Rails.root.join('script/export_lookbook_visual_regression_report.rb')

      class << self
        def enabled?
          Lookbook::VisualRegression.enabled?
        end

        def call!(name, refresh_report: true)
          new(name).call!(refresh_report: refresh_report)
        end

        def call_all!(refresh_report: true)
          report = Report.load
          names = report&.failed_previews&.map(&:name) || []
          raise Error, 'No failed previews to accept' if names.empty?

          names.each { |preview_name| call!(preview_name, refresh_report: false) }
          refresh_report! if refresh_report
          names
        end

        def refresh_report!
          raise Error, 'Export script missing' unless EXPORT_SCRIPT.exist?

          success = system('ruby', EXPORT_SCRIPT.to_s)
          raise Error, 'Failed to refresh visual regression report' unless success
        end
      end

      def initialize(name)
        @name = name.to_s
      end

      def call!(refresh_report: true)
        raise Error, 'Snapshot acceptance is disabled' unless self.class.enabled?
        raise Error, 'Unknown preview' unless PreviewCatalog.valid_name?(@name)

        actual = actual_path
        raise Error, 'No actual screenshot to accept' unless actual.exist?

        FileUtils.mkdir_p(SNAPSHOTS_DIR)
        FileUtils.cp(actual, snapshot_path)
        FailureArtifacts.clear!(@name)
        self.class.refresh_report! if refresh_report
        @name
      end

      private

      def actual_path
        Rails.root.join('public/lookbook-visual-regression', @name, 'actual.png')
      end

      def snapshot_path
        SNAPSHOTS_DIR.join("#{SnapshotBasename.normalize(@name)}-linux.png")
      end
    end
  end
end
