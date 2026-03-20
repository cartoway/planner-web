require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../scripts/cleanup_driver_shortlinks'

class CleanupDriverShortlinksTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir('cleanup_driver_shortlinks_test')
    @short_dir = File.join(@tmp_dir, 'short')
    @cache_dir = File.join(@tmp_dir, 'url_cache')
    FileUtils.mkdir_p(@short_dir)
    FileUtils.mkdir_p(@cache_dir)
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir) if @tmp_dir && Dir.exist?(@tmp_dir)
  end

  def test_deletes_only_matching_driver_token_links_and_related_cache
    # matching short link
    matched_short = nested_file(@short_dir, 'l/3/l3eu9a')
    File.write(matched_short, 'http://localhost:8080/routes/192/mobile?driver_token=token_abc')
    matched_code = File.basename(matched_short)

    # non-matching short link
    kept_short = nested_file(@short_dir, '4/0/40d6p9')
    File.write(kept_short, 'http://localhost:8080/routes/193/mobile?driver_token=another_token')
    kept_code = File.basename(kept_short)

    # matching cache entry (points to matched short code)
    matched_cache = nested_file(@cache_dir, '0/0/00d6ac389aaf9523')
    File.write(matched_cache, matched_code)

    # non-matching cache entry (points to kept short code)
    kept_cache = nested_file(@cache_dir, '1/4/14529cc8c6a13eb9')
    File.write(kept_cache, kept_code)

    result = CleanupDriverShortlinks.new(tokens: ['token_abc'], storage_path: @tmp_dir).call

    assert_equal 1, result[:deleted_short]
    assert_equal 1, result[:deleted_cache]
    refute File.exist?(matched_short)
    refute File.exist?(matched_cache)
    assert File.exist?(kept_short)
    assert File.exist?(kept_cache)
  end

  def test_returns_zero_when_no_token_provided
    result = CleanupDriverShortlinks.new(tokens: [], storage_path: @tmp_dir).call

    assert_equal({ deleted_short: 0, deleted_cache: 0 }, result)
  end

  private

  def nested_file(root, relative_path)
    path = File.join(root, relative_path)
    FileUtils.mkdir_p(File.dirname(path))
    path
  end
end
