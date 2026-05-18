# frozen_string_literal: true

module DesignSystem
  class ButtonsPreview < Lookbook::Preview
    layout 'lookbook_preview'

    def variants
      render_with_template
    end

    def sizes_and_states
      render_with_template
    end

    def icon_and_toolbar
      render_with_template
    end

    def button_groups
      render_with_template
    end
  end
end
