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
end
