# frozen_string_literal: true

module DesignSystem
  class FormsPreview < Lookbook::Preview
    layout 'lookbook_preview'

    def text_fields
      render_with_template
    end

    def input_groups
      render_with_template
    end

    def checks_and_switches
      render_with_template
    end

    def selects_and_textareas
      render_with_template
    end

    def validation
      render_with_template
    end
  end
end
