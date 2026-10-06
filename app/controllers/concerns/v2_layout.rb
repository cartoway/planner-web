# frozen_string_literal: true

# Shared v2 layout / turbo-frame helpers. Feature flag is User#layout_v2?
# (same preference as destinations_index_v2?).
module V2Layout
  extend ActiveSupport::Concern

  private

  def layout_v2?
    current_user&.layout_v2?
  end

  def v2_form_sidebar_request?
    turbo_frame_request? && turbo_frame_request_id == 'form_sidebar'
  end

  def v2_sidebar_submit?
    ActiveModel::Type::Boolean.new.cast(params[:v2_sidebar]) || v2_form_sidebar_request?
  end

  def render_v2_page(template)
    render template, layout: 'v2/layouts/application'
  end

  def render_v2_close_sidebar
    render 'v2/layouts/close_sidebar', layout: false
  end

  # Turbo Frame fragment, or the v2 list with the form inlined (shareable URL).
  # Returns true when it rendered. Admins have no customer — keep the standalone form.
  def render_v2_form_or_list(sidebar_template, index_template, list_url)
    if v2_form_sidebar_request?
      render sidebar_template, layout: false
      return true
    end
    return false unless layout_v2? && current_user&.customer

    yield if block_given?
    @v2_sidebar_template = "#{controller_path}/#{sidebar_template}"
    @v2_form_sidebar_list_url = list_url
    render_v2_page index_template
    true
  end
end
