require 'test_helper'

class LayerTest < ActiveSupport::TestCase
  test 'should not save' do
    layer = Layer.new
    assert_not layer.save, 'Saved without required fields'
  end

  test 'vector_url is optional' do
    layer = layers(:layer_one)
    layer.vector_url = 'https://example.com/maps/streets/style.json'
    assert layer.save
    assert_equal 'https://example.com/maps/streets/style.json', layer.reload.vector_url
  end

  test 'should translate name' do
    orig_locale = I18n.locale
    begin
      I18n.default_locale = :en
      layer = layers(:layer_one)
      layer2 = layers(:layer_two)

      I18n.locale = :fr
      assert_equal layer.translated_name, layer.name_locale['fr']
      assert_equal layer2.translated_name, layer2.name_locale['fr']

      I18n.locale = :en
      assert_equal layer.translated_name, layer.name_locale['en']
      assert_equal layer2.translated_name, layer2.name_locale['en']
    ensure
      I18n.locale = I18n.default_locale = orig_locale
    end
  end
end
