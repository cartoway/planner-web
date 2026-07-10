# frozen_string_literal: true

require 'fileutils'
require 'pathname'

module Lookbook
  module VisualRegression
    # Playwright failure artifacts under visual-regression/test-results.
    module FailureArtifacts
      class << self
        def failed?(name)
          basename = SnapshotBasename.normalize(name)
          expected_src = snapshots_dir.join("#{basename}-linux.png")
          actual_src = find_attachment(name, 'actual')
          diff_src = find_attachment(name, 'diff')

          return false unless actual_src || diff_src
          return true if diff_src && !actual_src
          return true unless expected_src.exist? && actual_src

          File.binread(expected_src) != File.binread(actual_src)
        end

        def clear!(name)
          basename = SnapshotBasename.normalize(name)
          return unless test_results_dir.directory?

          Dir.glob(test_results_dir.join('**', "#{basename}-*.png")).each do |path|
            FileUtils.rm_f(path)
          end
        end

        def find_attachment(name, suffix)
          return nil unless test_results_dir.directory?

          basename = SnapshotBasename.normalize(name)
          Dir.glob(test_results_dir.join('**', "#{basename}-#{suffix}.png")).first
        end

        def snapshots_dir
          repo_root.join('visual-regression/tests/lookbook.vrt.spec.ts-snapshots')
        end

        def test_results_dir
          repo_root.join('visual-regression/test-results')
        end

        def repo_root
          if defined?(Rails) && Rails.application
            Rails.root
          else
            Pathname.new(File.expand_path('../../../..', __dir__))
          end
        end
      end
    end
  end
end
