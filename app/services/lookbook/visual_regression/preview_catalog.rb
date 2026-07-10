# frozen_string_literal: true

module Lookbook
  module VisualRegression
    # Preview names and paths parsed from the Playwright spec (single source for validation).
    class PreviewCatalog
      SPEC_PATH = Rails.root.join('visual-regression/tests/lookbook.vrt.spec.ts')
      NAME_PATTERN = /\A[a-z0-9][a-z0-9_-]*\z/i

      class << self
        def entries
          return [] unless SPEC_PATH.exist?

          SPEC_PATH.read.scan(/\{\s*path:\s*'([^']+)',\s*name:\s*'([^']+)'/).map do |path, name|
            { path: path, name: name }
          end
        end

        def names
          entries.map { |entry| entry[:name] }
        end

        def valid_name?(name)
          name.to_s.match?(NAME_PATTERN) && names.include?(name.to_s)
        end
      end
    end
  end
end
