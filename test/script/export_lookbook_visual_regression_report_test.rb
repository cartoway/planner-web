# frozen_string_literal: true

require 'open3'
require 'test_helper'

class ExportLookbookVisualRegressionReportTest < ActiveSupport::TestCase
  test 'export script writes manifest.json from lookbook spec and snapshots' do
    script_path = Rails.root.join('script/export_lookbook_visual_regression_report.rb')
    spec_path = Rails.root.join('visual-regression/tests/lookbook.vrt.spec.ts')
    skip 'export script not present' unless script_path.exist?
    skip 'lookbook spec not present' unless spec_path.exist?

    Dir.mktmpdir('lookbook-vrt-export') do |public_dir|
      manifest_path = Pathname(public_dir).join('manifest.json')
      env = { 'LOOKBOOK_VRT_PUBLIC_DIR' => public_dir }

      output = nil
      success = false
      status = nil

      Open3.popen2e(env, 'ruby', script_path.to_s) do |_stdin, stdout_err, wait_thr|
        output = stdout_err.read
        status = wait_thr.value
        success = status.success?
      end

      assert success, "export script should exit successfully (status #{status&.exitstatus})\n#{output}"
      assert_predicate manifest_path, :exist?

      manifest = JSON.parse(manifest_path.read)
      assert manifest['previews'].is_a?(Array)
      assert manifest['previews'].any?
      assert_equal manifest['previews'].size, manifest['passed_count'] + manifest['failed_count']
    end
  end
end
