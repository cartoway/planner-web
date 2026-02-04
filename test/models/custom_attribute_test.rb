require 'test_helper'

class CustomAttributeTest < ActiveSupport::TestCase
  setup do
    @customer = customers(:customer_one)
  end

  test 'should require name' do
    custom_attribute = CustomAttribute.new(
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )
    refute custom_attribute.valid?
    assert_includes custom_attribute.errors[:name], I18n.t('errors.messages.blank')
  end

  test 'should require customer' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle'
    )
    refute custom_attribute.valid?
    assert custom_attribute.errors[:customer].any?, "customer should have validation errors"
  end

  test 'should strip whitespace from name' do
    custom_attribute = CustomAttribute.create!(
      name: '  test_name  ',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )
    assert_equal 'test_name', custom_attribute.name
  end

  test 'should not allow duplicate names for same object_class and customer without related_field' do
    CustomAttribute.create!(
      name: 'duplicate_name',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      related_field: nil
    )

    duplicate = CustomAttribute.new(
      name: 'duplicate_name',
      object_type: 'integer',
      object_class: 'vehicle',
      customer: @customer,
      related_field: nil
    )
    refute duplicate.valid?
    assert_includes duplicate.errors[:name], I18n.t('errors.messages.taken')
  end

  test 'should allow duplicate names for different customers' do
    customer2 = customers(:customer_two)
    CustomAttribute.create!(
      name: 'shared_name',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )

    duplicate = CustomAttribute.new(
      name: 'shared_name',
      object_type: 'string',
      object_class: 'vehicle',
      customer: customer2
    )
    assert duplicate.valid?, "Should allow duplicate names for different customers: #{duplicate.errors.full_messages}"
  end

  test 'should allow duplicate names for different object_classes' do
    CustomAttribute.create!(
      name: 'shared_name',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )

    duplicate = CustomAttribute.new(
      name: 'shared_name',
      object_type: 'string',
      object_class: 'visit',
      customer: @customer
    )
    assert duplicate.valid?, "Should allow duplicate names for different object_classes: #{duplicate.errors.full_messages}"
  end

  test 'should accept boolean object_type' do
    custom_attribute = CustomAttribute.new(
      name: 'test_bool',
      object_type: 'boolean',
      object_class: 'vehicle',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'boolean', custom_attribute.object_type
  end

  test 'should accept string object_type' do
    custom_attribute = CustomAttribute.new(
      name: 'test_string',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'string', custom_attribute.object_type
  end

  test 'should accept integer object_type' do
    custom_attribute = CustomAttribute.new(
      name: 'test_integer',
      object_type: 'integer',
      object_class: 'vehicle',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'integer', custom_attribute.object_type
  end

  test 'should accept float object_type' do
    custom_attribute = CustomAttribute.new(
      name: 'test_float',
      object_type: 'float',
      object_class: 'vehicle',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'float', custom_attribute.object_type
  end

  test 'should accept array object_type' do
    custom_attribute = CustomAttribute.new(
      name: 'test_array',
      object_type: 'array',
      object_class: 'vehicle',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'array', custom_attribute.object_type
  end

  test 'should accept vehicle object_class' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'vehicle', custom_attribute.object_class
  end

  test 'should accept visit object_class' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'visit',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'visit', custom_attribute.object_class
  end

  test 'should accept stop_visit object_class' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'stop_visit',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'stop_visit', custom_attribute.object_class
  end

  test 'should accept stop_store object_class' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'stop_store',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'stop_store', custom_attribute.object_class
  end

  test 'should accept route object_class' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'route',
      customer: @customer
    )
    assert custom_attribute.valid?
    assert_equal 'route', custom_attribute.object_class
  end

  test 'should refuse stop object_class' do
    assert_raise(ArgumentError) do
      CustomAttribute.new(
        name: 'test',
        object_type: 'string',
        object_class: 'stop',
        customer: @customer
      )
    end
  end

  test 'typed_default_value should cast boolean correctly' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'boolean',
      object_class: 'vehicle',
      customer: @customer,
      default_value: '1'
    )
    assert_equal true, custom_attribute.typed_default_value
  end

  test 'typed_default_value should cast integer correctly' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'integer',
      object_class: 'vehicle',
      customer: @customer,
      default_value: '42'
    )
    assert_equal 42, custom_attribute.typed_default_value
  end

  test 'typed_default_value should cast float correctly' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'float',
      object_class: 'vehicle',
      customer: @customer,
      default_value: '3.14'
    )
    assert_equal 3.14, custom_attribute.typed_default_value
  end

  test 'typed_default_value should parse array correctly' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'array',
      object_class: 'vehicle',
      customer: @customer,
      default_value: '["option1", "option2"]'
    )
    assert_equal ['option1', 'option2'], custom_attribute.typed_default_value
  end

  test 'typed_default_value should return empty array for array type when default_value is nil' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'array',
      object_class: 'vehicle',
      customer: @customer,
      default_value: nil
    )
    assert_equal [], custom_attribute.typed_default_value
  end

  test 'typed_default_value should return string as-is' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      default_value: 'test string'
    )
    assert_equal 'test string', custom_attribute.typed_default_value
  end

  test 'display_default_value should cast boolean correctly' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'boolean',
      object_class: 'vehicle',
      customer: @customer,
      default_value: '1'
    )
    assert_equal true, custom_attribute.display_default_value
  end

  test 'display_default_value should join array values with /' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'array',
      object_class: 'vehicle',
      customer: @customer,
      default_value: '["option1", "option2"]'
    )
    assert_equal 'option1 / option2', custom_attribute.display_default_value
  end

  test 'display_default_value should return empty array for array type when default_value is nil' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'array',
      object_class: 'vehicle',
      customer: @customer,
      default_value: nil
    )
    assert_equal [], custom_attribute.display_default_value
  end

  test 'for_vehicle scope should filter by vehicle object_class' do
    ca1 = CustomAttribute.create!(
      name: 'vehicle_attr',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )
    ca2 = CustomAttribute.create!(
      name: 'visit_attr',
      object_type: 'string',
      object_class: 'visit',
      customer: @customer
    )

    result = CustomAttribute.for_vehicle
    assert_includes result, ca1
    refute_includes result, ca2
  end

  test 'for_visit scope should filter by visit object_class' do
    ca1 = CustomAttribute.create!(
      name: 'visit_attr',
      object_type: 'string',
      object_class: 'visit',
      customer: @customer
    )
    ca2 = CustomAttribute.create!(
      name: 'vehicle_attr',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )

    result = CustomAttribute.for_visit
    assert_includes result, ca1
    refute_includes result, ca2
  end

  test 'for_stop_visit scope should filter by stop_visit object_class' do
    ca1 = CustomAttribute.create!(
      name: 'stop_visit_attr',
      object_type: 'string',
      object_class: 'stop_visit',
      customer: @customer
    )
    ca2 = CustomAttribute.create!(
      name: 'stop_store_attr',
      object_type: 'string',
      object_class: 'stop_store',
      customer: @customer
    )

    result = CustomAttribute.for_stop_visit
    assert_includes result, ca1
    refute_includes result, ca2
  end

  test 'for_stop_store scope should filter by stop_store object_class' do
    ca1 = CustomAttribute.create!(
      name: 'stop_store_attr',
      object_type: 'string',
      object_class: 'stop_store',
      customer: @customer
    )
    ca2 = CustomAttribute.create!(
      name: 'stop_visit_attr',
      object_type: 'string',
      object_class: 'stop_visit',
      customer: @customer
    )

    result = CustomAttribute.for_stop_store
    assert_includes result, ca1
    refute_includes result, ca2
  end

  test 'for_route scope should filter by route object_class' do
    ca1 = CustomAttribute.create!(
      name: 'route_attr',
      object_type: 'string',
      object_class: 'route',
      customer: @customer
    )
    ca2 = CustomAttribute.create!(
      name: 'vehicle_attr',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer
    )

    result = CustomAttribute.for_route
    assert_includes result, ca1
    refute_includes result, ca2
  end

  test 'ordered_object_classes should include all object_classes' do
    classes = CustomAttribute.ordered_object_classes
    assert_includes classes, 'vehicle'
    assert_includes classes, 'visit'
    assert_includes classes, 'stop_visit'
    assert_includes classes, 'stop_store'
    assert_includes classes, 'route'
  end

  test 'default_value_to_type should convert default_value when object_type changes to boolean' do
    custom_attribute = CustomAttribute.create!(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      default_value: 'some string'
    )
    custom_attribute.object_type = 'boolean'
    custom_attribute.save!
    assert_equal "0", custom_attribute.default_value
    assert_equal false, custom_attribute.typed_default_value
  end

  test 'default_value_to_type should convert default_value when object_type changes to integer' do
    custom_attribute = CustomAttribute.create!(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      default_value: 'some string'
    )
    custom_attribute.object_type = 'integer'
    custom_attribute.save!
    assert_equal 'some string', custom_attribute.default_value
    assert_equal 0, custom_attribute.typed_default_value
  end

  test 'default_value_to_type should convert default_value when object_type changes to float' do
    custom_attribute = CustomAttribute.create!(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      default_value: 'some string'
    )
    custom_attribute.object_type = 'float'
    custom_attribute.save!
    assert_equal 'some string', custom_attribute.default_value
    assert_equal 0.0, custom_attribute.typed_default_value
  end

  test 'default_value_to_type should convert default_value when object_type changes to array' do
    custom_attribute = CustomAttribute.create!(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      default_value: 'some string'
    )
    custom_attribute.object_type = 'array'
    custom_attribute.save!
    assert_equal '[""]', custom_attribute.default_value
    assert_equal [''], custom_attribute.typed_default_value
  end

  test 'default_value_to_type should convert default_value when object_type changes to string' do
    custom_attribute = CustomAttribute.create!(
      name: 'test',
      object_type: 'integer',
      object_class: 'vehicle',
      customer: @customer,
      default_value: 42
    )
    custom_attribute.object_type = 'string'
    custom_attribute.save!
    assert_equal '42', custom_attribute.default_value
    assert_equal '42', custom_attribute.typed_default_value
  end
  test 'default_value_to_type should not convert default_value if object_type does not change' do
    custom_attribute = CustomAttribute.create!(
      name: 'test',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      default_value: 'some string'
    )
    original_value = custom_attribute.default_value
    custom_attribute.name = 'updated_name'
    custom_attribute.save!
    assert_equal original_value, custom_attribute.default_value
    assert_equal original_value, custom_attribute.typed_default_value
  end

  test 'should allow nil related_field' do
    custom_attribute = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      related_field: nil
    )
    assert custom_attribute.valid?, "Custom attribute should be valid with nil related_field: #{custom_attribute.errors.full_messages}"
  end

  test 'should allow valid related_field for route' do
    custom_attribute = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'start_route_data'
    )
    assert custom_attribute.valid?, "Custom attribute should be valid with start_route_data: #{custom_attribute.errors.full_messages}"
  end

  test 'should allow stop_route_data as related_field for route' do
    custom_attribute = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'stop_route_data'
    )
    assert custom_attribute.valid?, "Custom attribute should be valid with stop_route_data: #{custom_attribute.errors.full_messages}"
  end

  test 'should reject invalid related_field for route' do
    custom_attribute = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'invalid_field'
    )
    refute custom_attribute.valid?, "Custom attribute should not be valid with invalid_field"
    assert custom_attribute.errors[:related_field].any?, "related_field should have validation errors"
  end

  test 'should reject related_field for object_class that does not support it' do
    custom_attribute = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      related_field: 'start_route_data'
    )
    refute custom_attribute.valid?, "Custom attribute should not be valid with related_field for vehicle"
    assert custom_attribute.errors[:related_field].any?, "related_field should have validation errors"
  end

  # Tests for uniqueness with related_field
  test 'should allow duplicate names with different related_fields' do
    CustomAttribute.create!(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'start_route_data'
    )

    custom_attribute2 = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'stop_route_data'
    )
    assert custom_attribute2.valid?, "Should allow duplicate names with different related_fields: #{custom_attribute2.errors.full_messages}"
  end

  test 'should allow duplicate names with nil related_field' do
    CustomAttribute.create!(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: nil
    )

    custom_attribute2 = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'start_route_data'
    )
    assert custom_attribute2.valid?, "Should allow duplicate names with nil vs present related_field: #{custom_attribute2.errors.full_messages}"
  end

  test 'should not allow duplicate names with same related_field' do
    CustomAttribute.create!(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'start_route_data'
    )

    custom_attribute2 = CustomAttribute.new(
      name: 'test_attribute',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'start_route_data'
    )
    refute custom_attribute2.valid?, "Should not allow duplicate names with same related_field"
    assert_includes custom_attribute2.errors[:name], I18n.t('errors.messages.taken')
  end

  # Tests for valid_related_fields method
  test 'valid_related_fields should return empty array for vehicle' do
    custom_attribute = CustomAttribute.new(object_class: 'vehicle')
    assert_equal [], custom_attribute.valid_related_fields
  end

  test 'valid_related_fields should return start_route_data and stop_route_data for route' do
    custom_attribute = CustomAttribute.new(object_class: 'route')
    valid_fields = custom_attribute.valid_related_fields
    assert_includes valid_fields, 'start_route_data'
    assert_includes valid_fields, 'stop_route_data'
    assert_equal 2, valid_fields.size
  end

  test 'valid_related_fields should return empty array when object_class is nil' do
    custom_attribute = CustomAttribute.new
    assert_equal [], custom_attribute.valid_related_fields
  end

  # Tests for related_fields? method
  test 'related_fields? should return false for vehicle' do
    custom_attribute = CustomAttribute.new(object_class: 'vehicle')
    refute custom_attribute.related_fields?
  end

  test 'related_fields? should return true for route' do
    custom_attribute = CustomAttribute.new(object_class: 'route')
    assert custom_attribute.related_fields?
  end

  # Tests for scopes
  test 'for_related_field scope should filter by related_field' do
    ca1 = CustomAttribute.create!(
      name: 'attr1',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'start_route_data'
    )
    ca2 = CustomAttribute.create!(
      name: 'attr2',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'stop_route_data'
    )

    result = CustomAttribute.for_related_field('start_route_data')
    assert_includes result, ca1
    refute_includes result, ca2
  end

  test 'without_related_field scope should return only attributes without related_field' do
    ca1 = CustomAttribute.create!(
      name: 'attr1',
      object_type: 'string',
      object_class: 'vehicle',
      customer: @customer,
      related_field: nil
    )
    ca2 = CustomAttribute.create!(
      name: 'attr2',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      related_field: 'start_route_data'
    )

    result = CustomAttribute.without_related_field
    assert_includes result, ca1
    refute_includes result, ca2
  end

  # Tests for class methods
  test 'related_fields_for should return fields for route' do
    fields = CustomAttribute.related_fields_for('route')
    assert_equal [:start_route_data, :stop_route_data], fields
  end

  test 'related_fields_for should return empty array for vehicle' do
    fields = CustomAttribute.related_fields_for('vehicle')
    assert_equal [], fields
  end

  test 'related_fields_for should return empty array for unknown object_class' do
    fields = CustomAttribute.related_fields_for('unknown')
    assert_equal [], fields
  end

  test 'parse_object_class_value should parse combined value' do
    object_class, related_field = CustomAttribute.parse_object_class_value('route:start_route_data')
    assert_equal 'route', object_class
    assert_equal 'start_route_data', related_field
  end

  test 'parse_object_class_value should parse value without related_field' do
    object_class, related_field = CustomAttribute.parse_object_class_value('vehicle')
    assert_equal 'vehicle', object_class
    assert_nil related_field
  end

  test 'parse_object_class_value should return nil for blank value' do
    object_class, related_field = CustomAttribute.parse_object_class_value('')
    assert_nil object_class
    assert_nil related_field
  end

  test 'parse_object_class_value should handle nil' do
    object_class, related_field = CustomAttribute.parse_object_class_value(nil)
    assert_nil object_class
    assert_nil related_field
  end

  test 'object_class_options_with_related_fields should include route with related_fields' do
    options = CustomAttribute.object_class_options_with_related_fields
    assert_includes options, 'route:start_route_data'
    assert_includes options, 'route:stop_route_data'
  end

  test 'object_class_options_with_related_fields should include vehicle without related_field' do
    options = CustomAttribute.object_class_options_with_related_fields
    assert_includes options, 'vehicle'
  end

  # Tests for virtual attribute object_class_with_related_field
  test 'parse_object_class_with_related_field should set object_class and related_field from combined value' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      customer: @customer,
      object_class_with_related_field: 'route:start_route_data'
    )
    custom_attribute.valid?
    assert_equal 'route', custom_attribute.object_class
    assert_equal 'start_route_data', custom_attribute.related_field
  end

  test 'parse_object_class_with_related_field should set object_class without related_field' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      customer: @customer,
      object_class_with_related_field: 'vehicle'
    )
    custom_attribute.valid?
    assert_equal 'vehicle', custom_attribute.object_class
    assert_nil custom_attribute.related_field
  end

  test 'parse_object_class_with_related_field should not override if object_class_with_related_field is blank' do
    custom_attribute = CustomAttribute.new(
      name: 'test',
      object_type: 'string',
      object_class: 'route',
      customer: @customer,
      object_class_with_related_field: ''
    )
    custom_attribute.valid?
    assert_equal 'route', custom_attribute.object_class
  end
end
