# frozen_string_literal: true

# v2 `bootstrap_form` builder: same Cartoway overrides as v1 `BootstrapForm::FormBuilder`, duplicated here so you
# can change v2-only behaviour without touching `config/initializers/bootstrap_form.rb`.
# Pass `builder: BootstrapForm::V2FormBuilder` to `bootstrap_form_for` / `fields_for`.
module BootstrapForm
  class V2FormBuilder < FormBuilder
    # Copy of v1 `FormBuilder::SUBMIT_DEFAULTS` — edit for v2 submit rows only.
    SUBMIT_DEFAULTS = {
      action: nil,
      message: nil,
      icon: nil,
      button: nil,
      title: nil,
      disable_with: nil,
      col_class: nil,
      row_class: nil,
      disabled: false
    }.freeze

    # Copy of v1 defaults — v2 views often pass `label_col` / `control_col` explicitly; adjust here for v2-wide defaults.
    def default_label_col
      'col-md-offset-1 col-md-10'
    end

    def default_control_col
      'col-md-offset-1 col-md-10 field'
    end

    def default_layout
      :horizontal
    end

    def render_haml(haml, locals = {})
      Haml::Template.new { haml.strip_heredoc }.render(self, locals)
    end

    def submit(**options)
      opts = SUBMIT_DEFAULTS.merge(options)
      action = opts[:action] == 'new' ? 'create' : 'update'
      object = self.object.class.name.underscore

      output = render_haml <<-HAML, object: object, action: action, opts: opts
        %div{ id: "#{object}_div_input", class: "#{opts[:row_class] || 'row form-group'}" }
          %div{ class: "#{opts[:col_class] || 'col-md-offset-2 col-md-6'}" }
            %button{ name: 'button', type: 'submit', class: "#{opts[:button] || 'btn btn-primary'}", title: "#{opts[:title]}", disabled: opts[:disabled], data: opts[:disable_with] ? { disable_with:  "#{opts[:disable_with]}" } : {}}
              %i.fa{ class: "#{opts[:icon] || 'fa-floppy-disk'}" }
              = opts[:message] || I18n.t("helpers.submit.#{action}", model: I18n.t("activerecord.models.#{object.pluralize}.one"))
      HAML
      output.html_safe
    end

    # Bootstrap 5 prepend/append wrapper (v1 uses `.input-group-addon` in `Helpers::Bootstrap`).
    def input_group_content(content)
      return content if content.include?("btn")

      tag.span(content, class: "input-group-text")
    end
  end
end
