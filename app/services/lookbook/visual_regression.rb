# frozen_string_literal: true

module Lookbook
  module VisualRegression
    module_function

    # Visual regression tests run only when LOOKBOOK_VRT=1 (see devcontainer / compose).
    def enabled?
      ENV['LOOKBOOK_VRT'] == '1'
    end
  end
end
