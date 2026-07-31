# frozen_string_literal: true

class LayerVectorUrlInferrer
  TILE_PATH_PATTERN = %r{/(?:\d+/)?\{z\}/\{x\}/\{y\}\.png\z}i

  def self.normalize_url(url)
    return url if url.blank?

    normalized = url.to_s.gsub(/\s+/, '')
    normalized = "https://#{normalized.delete_prefix('http://')}" if normalized.start_with?('http://')
    normalized
  end

  def self.infer_vector_url(raster_url)
    normalized = normalize_url(raster_url)
    return normalized if normalized.blank?

    base, query = normalized.split('?', 2)
    style_base = base.sub(TILE_PATH_PATTERN, '/style.json')
    return normalized if style_base == base

    query ? "#{style_base}?#{query}" : style_base
  end

  def self.patch(attrs)
    result = attrs.stringify_keys
    explicit = result['vector_url'].presence
    return result.merge('vector_url' => explicit) if explicit

    raster = result['urlssl'].presence
    result.merge('vector_url' => (raster && infer_vector_url(raster)))
  end
end
