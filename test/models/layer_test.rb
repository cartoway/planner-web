require 'test_helper'

class LayerTest < ActiveSupport::TestCase
  test 'should not save' do
    layer = Layer.new
    assert_not layer.save, 'Saved without required fields'
  end

  test 'vector_style_url is optional' do
    layer = layers(:layer_one)
    layer.vector_style_url = 'https://example.com/maps/streets/style.json'
    assert layer.save
    assert_equal 'https://example.com/maps/streets/style.json', layer.reload.vector_style_url
  end

  test 'should translate name' do
    with_test_locale(:en) do
      layer = layers(:layer_one)
      layer2 = layers(:layer_two)

      I18n.with_locale(:fr) do
        assert_equal layer.translated_name, layer.name_locale['fr']
        assert_equal layer2.translated_name, layer2.name_locale['fr']
      end

      assert_equal layer.translated_name, layer.name_locale['en']
      assert_equal layer2.translated_name, layer2.name_locale['en']
    end
  end
end
