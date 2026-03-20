#!/usr/bin/env ruby
# frozen_string_literal: true

require 'find'

class CleanupDriverShortlinks
  def initialize(tokens:, storage_path: nil)
    @tokens = tokens.compact.map(&:to_s).reject(&:empty?).uniq
    @storage_path = (storage_path || ENV['STORAGE_PATH'] || '/data').to_s
    @short_dir = File.join(@storage_path, 'short')
    @url_cache_dir = File.join(@storage_path, 'url_cache')
  end

  def call
    return { deleted_short: 0, deleted_cache: 0 } if @tokens.empty?
    return { deleted_short: 0, deleted_cache: 0 } unless Dir.exist?(@short_dir)

    deleted_short_codes = delete_short_files
    deleted_cache = delete_cache_files(deleted_short_codes)

    { deleted_short: deleted_short_codes.size, deleted_cache: deleted_cache }
  end

  private

  def delete_short_files
    deleted_short_codes = {}

    Find.find(@short_dir) do |path|
      next unless File.file?(path)

      content = safe_read(path)
      next if content.nil?
      next unless @tokens.any? { |token| content.include?("driver_token=#{token}") }

      deleted_short_codes[File.basename(path)] = true
      File.delete(path)
    end

    deleted_short_codes.keys
  end

  def delete_cache_files(short_codes)
    return 0 if short_codes.empty?
    return 0 unless Dir.exist?(@url_cache_dir)

    deleted_cache = 0

    Find.find(@url_cache_dir) do |path|
      next unless File.file?(path)

      content = safe_read(path)
      next if content.nil?
      next unless short_codes.include?(content.strip)

      File.delete(path)
      deleted_cache += 1
    end

    deleted_cache
  end

  def safe_read(path)
    File.read(path)
  rescue StandardError
    nil
  end
end

if $0 == __FILE__
  result = CleanupDriverShortlinks.new(tokens: ARGV).call
  puts "Deleted short links: #{result[:deleted_short]}, cache entries: #{result[:deleted_cache]}"
end
