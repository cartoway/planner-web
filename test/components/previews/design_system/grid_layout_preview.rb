# frozen_string_literal: true

module DesignSystem
  # Bootstrap 5 grid: containers, rows, columns (see Lookbook templates for markup notes).
  class GridLayoutPreview < ApplicationPreview
    def rows_and_columns
      render_with_template
    end

    def gutters_and_nesting
      render_with_template
    end

    def breakpoints_and_offset
      render_with_template
    end
end
end
