require 'test_helper'

class CustomAttributes::FormattingHelperTest < ActionView::TestCase
  test 'test array to object_type' do
    object_type = 'boolean'
    raw_default_value = ['hello'].to_json
    assert_equal true, object_type_cast(object_type, raw_default_value)

    object_type = 'string'
    assert_equal 'hello', object_type_cast(object_type, raw_default_value)

    object_type = 'integer'
    assert_equal 0, object_type_cast(object_type, raw_default_value)

    object_type = 'float'
    assert_equal 0.0, object_type_cast(object_type, raw_default_value)
  end

  test 'mobile_custom_attributes_for returns all stop visit custom attributes' do
    customer = customers(:customer_one)
    stop = stops(:stop_one_one)

    result = mobile_custom_attributes_for(customer, stop)

    assert_includes result, custom_attributes(:custom_attribute_stop_one)
    assert_includes result, custom_attributes(:custom_attribute_stop_two)
  end

  test 'mobile_visit_custom_attributes_for returns only visible visit custom attributes' do
    customer = customers(:customer_one)

    result = mobile_visit_custom_attributes_for(customer)

    assert_includes result, custom_attributes(:custom_attribute_visit_visible)
    refute_includes result, custom_attributes(:custom_attribute_visit_hidden)
  end

  test 'mobile_vehicle_custom_attributes_for returns only visible vehicle custom attributes' do
    customer = customers(:customer_one)

    result = mobile_vehicle_custom_attributes_for(customer)

    assert_includes result, custom_attributes(:custom_attribute_one)
    refute_includes result, custom_attributes(:custom_attribute_vehicle_hidden)
  end

  test 'mobile_route_custom_attributes_for returns only visible route custom attributes without related field' do
    customer = customers(:customer_one)

    result = mobile_route_custom_attributes_for(customer)

    assert_includes result, custom_attributes(:custom_attribute_route_visible)
    refute_includes result, custom_attributes(:custom_attribute_route_hidden)
  end

  test 'format_custom_attribute_value formats by object type' do
    assert_equal I18n.t('all.value._yes'), format_custom_attribute_value(custom_attributes(:custom_attribute_stop_three), true)
    assert_equal I18n.t('all.value._no'), format_custom_attribute_value(custom_attributes(:custom_attribute_stop_three), false)

    formatted_integer = format_custom_attribute_value(custom_attributes(:custom_attribute_stop_two), 1250)
    assert_equal '1250', formatted_integer.to_s.gsub(/[^\d]/, '')
    assert_includes formatted_integer.to_s, '1'
    assert_includes formatted_integer.to_s, '250'

    assert_equal '3,2', format_custom_attribute_value(custom_attributes(:custom_attribute_four), 3.2)
    assert_equal 'default_stop_value', format_custom_attribute_value(custom_attributes(:custom_attribute_stop_one), 'default_stop_value')
  end
end
