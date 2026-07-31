# frozen_string_literal: true

require 'test_helper'

class LayerVectorStyleUrlInferrerTest < ActiveSupport::TestCase
  test 'normalizes whitespace and http in urls' do
    url = "https://maps.cartoway.com/styles/56.10-\nrestaurant/{z}/{x}/{y}.png"
    assert_equal 'https://maps.cartoway.com/styles/56.10-restaurant/{z}/{x}/{y}.png', LayerVectorStyleUrlInferrer.normalize_url(url)
  end

  test 'infers maptiler vector style url' do
    raster = 'https://api.maptiler.com/maps/streets-v2/256/{z}/{x}/{y}.png?key=abc'
    assert_equal 'https://api.maptiler.com/maps/streets-v2/style.json?key=abc', LayerVectorStyleUrlInferrer.infer_vector_style_url(raster)
  end

  test 'infers cartoway vector style url' do
    raster = 'https://maps.cartoway.com/styles/truck-restrictions/{z}/{x}/{y}.png'
    assert_equal 'https://maps.cartoway.com/styles/truck-restrictions/style.json', LayerVectorStyleUrlInferrer.infer_vector_style_url(raster)
  end

  test 'patch keeps explicit vector_style_url as-is' do
    patched = LayerVectorStyleUrlInferrer.patch(
      'url' => 'https://api.maptiler.com/maps/dataviz/256/{z}/{x}/{y}.png?key=abc',
      'vector_style_url' => 'https://maps.example.com/styles/custom/style.json'
    )
    assert_equal 'https://maps.example.com/styles/custom/style.json', patched['vector_style_url']
  end

  test 'patch infers vector_style_url from url when absent' do
    patched = LayerVectorStyleUrlInferrer.patch(
      'url' => 'https://maps.cartoway.com/styles/truck-restrictions/{z}/{x}/{y}.png'
    )
    assert_equal 'https://maps.cartoway.com/styles/truck-restrictions/style.json', patched['vector_style_url']
  end
end
