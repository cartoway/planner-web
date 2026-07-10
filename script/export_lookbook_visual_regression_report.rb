#!/usr/bin/env ruby
# frozen_string_literal: true

# Builds public/lookbook-visual-regression/manifest.json (+ PNG copies) from Playwright output.
# Invoked after `npx playwright test` (see .devcontainer/run-lookbook-vrt-on-start.sh).

require 'fileutils'
require 'json'
require 'pathname'
require 'time'

root = Pathname.new(File.expand_path('..', __dir__))
$:.unshift root.join('app/services').to_s
require 'lookbook/visual_regression/snapshot_basename'
require 'lookbook/visual_regression/failure_artifacts'

def snapshot_basename(name)
  Lookbook::VisualRegression::SnapshotBasename.normalize(name)
end

def find_attachment(test_results_dir, name, suffix)
  Lookbook::VisualRegression::FailureArtifacts.find_attachment(name, suffix)
end

def preview_failed?(name)
  Lookbook::VisualRegression::FailureArtifacts.failed?(name)
end

def copy_attachment(source, preview_dir, filename, public_prefix, name)
  return nil unless source && File.exist?(source)

  FileUtils.cp(source, preview_dir.join(filename))
  "#{public_prefix}/#{name}/#{filename}"
end

root = Pathname.new(File.expand_path('..', __dir__))
spec_path = root.join('visual-regression/tests/lookbook.vrt.spec.ts')
snapshots_dir = root.join('visual-regression/tests/lookbook.vrt.spec.ts-snapshots')
test_results_dir = root.join('visual-regression/test-results')
public_dir = Pathname(ENV.fetch('LOOKBOOK_VRT_PUBLIC_DIR', root.join('public/lookbook-visual-regression').to_s))
public_prefix = '/lookbook-visual-regression'

unless spec_path.exist?
  warn "Missing #{spec_path}"
  exit 1
end

previews = spec_path.read.scan(/\{\s*path:\s*'([^']+)',\s*name:\s*'([^']+)'/).map do |path, name|
  { 'path' => path, 'name' => name }
end

FileUtils.rm_rf(public_dir) if public_dir.directory?
FileUtils.mkdir_p(public_dir)

rows = previews.map do |preview|
  name = preview['name']
  preview_dir = public_dir.join(name)
  FileUtils.rm_rf(preview_dir) if preview_dir.directory?
  FileUtils.mkdir_p(preview_dir)

  expected_src = snapshots_dir.join("#{snapshot_basename(name)}-linux.png")
  expected_url = nil
  if expected_src.exist?
    FileUtils.cp(expected_src, preview_dir.join('expected.png'))
    expected_url = "#{public_prefix}/#{name}/expected.png?v=#{expected_src.mtime.to_i}"
  end

  actual_src = find_attachment(test_results_dir, name, 'actual')
  diff_src = find_attachment(test_results_dir, name, 'diff')
  failed = preview_failed?(name)

  actual_url = failed ? copy_attachment(actual_src, preview_dir, 'actual.png', public_prefix, name) : nil
  diff_url = failed ? copy_attachment(diff_src, preview_dir, 'diff.png', public_prefix, name) : nil
  FileUtils.rm_f(preview_dir.join('actual.png')) unless failed
  FileUtils.rm_f(preview_dir.join('diff.png')) unless failed

  preview.merge(
    'status' => failed ? 'failed' : 'passed',
    'expected_url' => expected_url,
    'actual_url' => actual_url,
    'diff_url' => diff_url,
    'lookbook_preview_url' => "/lookbook/preview/#{preview['path']}"
  )
end

passed_count = rows.count { |row| row['status'] == 'passed' }
failed_count = rows.count { |row| row['status'] == 'failed' }

manifest = {
  'generated_at' => Time.now.utc.iso8601,
  'status' => failed_count.zero? ? 'passed' : 'failed',
  'passed_count' => passed_count,
  'failed_count' => failed_count,
  'previews' => rows
}

File.write(public_dir.join('manifest.json'), JSON.pretty_generate(manifest))
puts "Lookbook VRT report: #{failed_count} failed, #{passed_count} passed → #{public_dir.join('manifest.json')}"
