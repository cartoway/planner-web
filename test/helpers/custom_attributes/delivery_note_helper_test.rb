require 'test_helper'

class CustomAttributes::DeliveryNoteHelperTest < ActionView::TestCase
  helper CustomAttributes::FormattingHelper

  test 'delivery_note_custom_attribute_value uses check marks for booleans' do
    stop = stops(:stop_one_one)
    ca = custom_attributes(:custom_attribute_stop_three)

    stop.update_columns(custom_attributes: { 'stop_urgent' => true })
    assert_equal '✓', delivery_note_custom_attribute_value(ca, Stop.find(stop.id))

    stop.update_columns(custom_attributes: { 'stop_urgent' => false })
    assert_equal '✗', delivery_note_custom_attribute_value(ca, Stop.find(stop.id))
  end

  test 'delivery_note hides custom attributes without value and without default' do
    stop = stops(:stop_one_one)
    ca = custom_attributes(:custom_attribute_stop_one)
    original_default = ca.default_value

    ca.update_columns(default_value: nil)
    stop.update_columns(custom_attributes: { 'stop_custom_field' => '' })
    refute delivery_note_custom_attribute_displayable?(ca, Stop.find(stop.id))

    stop.update_columns(custom_attributes: {})
    refute delivery_note_custom_attribute_displayable?(ca, Stop.find(stop.id))

    ca.update_columns(default_value: 'fallback')
    assert delivery_note_custom_attribute_displayable?(ca, Stop.find(stop.id))
    assert_equal 'fallback', delivery_note_custom_attribute_value(ca, Stop.find(stop.id))

    stop.update_columns(custom_attributes: { 'stop_custom_field' => 'filled' })
    assert delivery_note_custom_attribute_displayable?(ca, Stop.find(stop.id))
    assert_equal 'filled', delivery_note_custom_attribute_value(ca, Stop.find(stop.id))
  ensure
    ca&.update_columns(default_value: original_default) if ca && original_default
  end

  test 'delivery note hides a list attribute when no option is selected' do
    stop = stops(:stop_one_one)
    ca = custom_attributes(:custom_attribute_stop_one)
    original_type = ca.object_type
    original_default = ca.default_value
    options = '["101-Anomalie","102-Anomalie"]'

    ca.update_columns(object_type: CustomAttribute.object_types[:array], default_value: options)
    stop.update_columns(custom_attributes: {})
    refute delivery_note_custom_attribute_displayable?(ca, Stop.find(stop.id))

    stop.update_columns(custom_attributes: { 'stop_custom_field' => options })
    refute delivery_note_custom_attribute_displayable?(ca, Stop.find(stop.id))

    stop.update_columns(custom_attributes: { 'stop_custom_field' => '101-Anomalie' })
    assert delivery_note_custom_attribute_displayable?(ca, Stop.find(stop.id))
    assert_equal '101-Anomalie', delivery_note_custom_attribute_value(ca, Stop.find(stop.id))
  ensure
    ca&.update_columns(object_type: original_type, default_value: original_default) if ca
  end
end
