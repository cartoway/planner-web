# frozen_string_literal: true

require 'test_helper'

class V2Bootstrap5GridMarkupTest < ActiveSupport::TestCase
  FORBIDDEN_PATTERNS = [
    /col-(xs|sm|md|lg)-offset-/,
    /\bcol-xs-/,
    /\bhidden-print\b/,
    /\bpull-right\b/,
    /\bpull-left\b/
  ].freeze

  test 'v2 views use Bootstrap 5 grid utilities instead of Bootstrap 3 classes' do
    view_root = Rails.root.join('app/views/v2')
    offenders = []

    Dir.glob(view_root.join('**/*')).each do |path|
      next unless File.file?(path)
      next unless path.end_with?('.haml', '.erb', '.html')

      content = File.read(path)
      FORBIDDEN_PATTERNS.each do |pattern|
        offenders << "#{path.sub("#{Rails.root}/", '')}: #{pattern.inspect}" if content.match?(pattern)
      end
    end

    assert_empty offenders, "Bootstrap 3 markup found in v2 views:\n#{offenders.join("\n")}"
  end
end
