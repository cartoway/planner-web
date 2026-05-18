# frozen_string_literal: true

module DesignSystem
  class TablesPreview < Lookbook::Preview
    layout 'lookbook_preview'

    def destinations_list
      render_with_template
    end

    def compact_and_striped
      render_with_template
    end
  end
end
