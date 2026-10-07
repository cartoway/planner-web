# frozen_string_literal: true

# Shared v2 layout / turbo-frame helpers. Feature flag is User#layout_v2?
# (same preference as destinations_index_v2?).
#
# List refresh after sidebar save / row actions (fleet, deliverable units, …):
#   1. Give the row/block `id: dom_id(record)` (or a stable container id for append).
#   2. Respond with turbo_stream via render_streams / stream_* (close frame + mutate list).
# Map-backed indexes (destinations, stores) may still refresh a turbo-frame instead.
module V2Layout
  extend ActiveSupport::Concern

  private

  def layout_v2?
    current_user&.layout_v2?
  end

  def form_sidebar_request?
    turbo_frame_request? && turbo_frame_request_id == 'form_sidebar'
  end

  def sidebar_submit?
    ActiveModel::Type::Boolean.new.cast(params[:v2_sidebar]) || form_sidebar_request?
  end

  def render_page(template)
    render template, layout: 'v2/layouts/application'
  end

  def render_close_sidebar
    render 'v2/layouts/close_sidebar', layout: false
  end

  # Validation errors after a Drive (_top) sidebar submit: put the form back in the frame.
  def render_sidebar_stream(name, status: :unprocessable_entity)
    html = render_to_string(
      template: "#{controller_path}/#{name}",
      formats: [:html],
      layout: false
    )
    render turbo_stream: turbo_stream.replace('form_sidebar', html: html), status: status
  end

  def stream_target(record_or_id)
    record_or_id.is_a?(String) || record_or_id.is_a?(Symbol) ? record_or_id.to_s : helpers.dom_id(record_or_id)
  end

  def stream_replace(record_or_id, partial:, locals: {})
    turbo_stream.replace(stream_target(record_or_id), partial: partial, locals: locals)
  end

  def stream_append(container_id, partial:, locals: {})
    turbo_stream.append(container_id, partial: partial, locals: locals)
  end

  def stream_remove(record_or_id)
    turbo_stream.remove(stream_target(record_or_id))
  end

  # Success path: clear frame contents (update, not replace — keep the same turbo-frame node) + list streams.
  # close_sidebar: nil => close when this was a sidebar form submit.
  def render_streams(*streams, close_sidebar: nil)
    close = close_sidebar.nil? ? sidebar_submit? : close_sidebar
    streams = Array(streams).flatten.compact
    if close
      render turbo_stream: [
        turbo_stream.update('form_sidebar', partial: 'v2/layouts/form_sidebar_placeholder'),
        *streams
      ]
    else
      render turbo_stream: streams
    end
  end

  # Turbo Frame fragment, or the v2 list with the form inlined (shareable URL).
  # Admins have no customer — keep the standalone form (caller renders nothing else).
  def render_form_or_list(sidebar_template, index_template, list_url)
    if form_sidebar_request?
      render sidebar_template, layout: false
      return
    end
    return unless layout_v2? && current_user&.customer

    yield if block_given?
    @sidebar_template = "#{controller_path}/#{sidebar_template}"
    @form_sidebar_list_url = list_url
    render_page index_template
  end
end
