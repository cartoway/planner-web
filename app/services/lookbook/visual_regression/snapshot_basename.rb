# frozen_string_literal: true

module Lookbook
  module VisualRegression
    # Playwright snapshot files replace underscores with dashes in basenames.
    module SnapshotBasename
      module_function

      def normalize(name)
        name.to_s.tr('_', '-')
      end
    end
  end
end
