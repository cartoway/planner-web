require 'test_helper'

class VisitTest < ActiveSupport::TestCase

  setup do
    @visit = visits(:visit_one)
  end

  test 'should not save' do
    visit = Visit.new
    assert_not visit.save, 'Saved without required fields'
  end

  test 'should update add tag' do
    destination = destinations(:destination_one)
    stops(:stop_three_one).destroy
    assert_difference('Stop.count', destination.customer.plannings.select{ |planning| planning.tags.include?(tags(:tag_two)) }.count) do
      destination.visits[0].tags << tags(:tag_two)
      destination.save!
      destination.customer.save!
    end
  end

  test 'should update remove tag' do
    destination = destinations(:destination_one)
    stops(:stop_three_one).destroy
    assert_difference('Stop.count', -1) do
      destination.visits[0].tags = []
      destination.save!
      destination.customer.save!
    end
  end

  test 'should update tag' do
    destination = destinations(:destination_one)
    planing = plannings(:planning_one)
    stops(:stop_three_one).destroy
    planing.tags = [tags(:tag_one), tags(:tag_two)]

    routes(:route_one_one).stops.clear
    destination.visits[0].tags = []

    assert_difference('Stop.count', 0) do
      destination.visits[0].tags = [tags(:tag_one)]
      destination.save!
      destination.customer.save!
    end

    assert_difference('Stop.count', 2) do
      destination.visits[0].tags = [tags(:tag_one), tags(:tag_two)]
      destination.save!
      destination.customer.save!
    end
  end

  test 'should set same start and close' do
    destination = destinations(:destination_one)
    visit = destination.visits[0]
    visit.time_window_start_1 = visit.time_window_end_1 = Time.new(2000, 01, 01, 00, 10, 00, '+00:00')
    destination.save!
  end

  test 'should validate open and close time exceeding one day' do
    destination = destinations(:destination_one)
    visit = destination.visits[0]
    visit.update time_window_start_1: '08:00', time_window_end_1: '12:00'
    assert visit.valid?
    assert_equal visit.time_window_end_1, 12 * 3_600
    visit.update time_window_start_2: '18:00', time_window_end_2: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_end_2, 32 * 3_600
  end

  test 'should validate open and close time from different type' do
    destination = destinations(:destination_one)
    visit = destination.visits[0]
    visit.update time_window_start_1: '08:00', time_window_end_1: 32 * 3_600
    assert visit.valid?
    assert_equal visit.time_window_end_1, 32 * 3_600
    visit.update time_window_start_1: '08:00', time_window_end_1: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_end_1, 32 * 3_600
    visit.update time_window_start_1: '08:00', time_window_end_1: 115200.0
    assert visit.valid?
    assert_equal visit.time_window_end_1, 32 * 3_600
    visit.update time_window_start_1: Time.parse('08:00'), time_window_end_1: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_start_1, 8 * 3_600
    visit.update time_window_start_1: DateTime.parse('2011-01-01 08:00'), time_window_end_1: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_start_1, 8 * 3_600
    visit.update time_window_start_1: 8.hours, time_window_end_1: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_start_1, 8 * 3_600

    visit.update time_window_start_1: '06:00', time_window_end_1: '07:00'
    visit.update time_window_start_2: '08:00', time_window_end_2: 32 * 3_600
    assert visit.valid?
    assert_equal visit.time_window_end_2, 32 * 3_600
    visit.update time_window_start_2: '08:00', time_window_end_2: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_end_2, 32 * 3_600
    visit.update time_window_start_2: '08:00', time_window_end_2: 115200.0
    assert visit.valid?
    assert_equal visit.time_window_end_2, 32 * 3_600
    visit.update time_window_start_2: Time.parse('08:00'), time_window_end_2: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_start_2, 8 * 3_600
    visit.update time_window_start_2: DateTime.parse('2011-01-01 08:00'), time_window_end_2: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_start_2, 8 * 3_600
    visit.update time_window_start_2: 8.hours, time_window_end_2: '32:00'
    assert visit.valid?
    assert_equal visit.time_window_start_2, 8 * 3_600
  end

  test 'should set invalid TW' do
    destination = destinations(:destination_one)
    visit = destination.visits[0]
    visit.time_window_start_1 = Time.new(2000, 01, 01, 00, 10, 00, '+00:00')
    visit.time_window_end_1 = Time.new(2000, 01, 01, 00, 9, 00, '+00:00')
    assert !destination.save

    visit.time_window_start_1 = Time.new(2000, 01, 01, 00, 10, 00, '+00:00')
    visit.time_window_start_2 = Time.new(2000, 01, 01, 00, 11, 00, '+00:00')
    assert !destination.save

    visit.time_window_start_1 = Time.new(2000, 01, 01, 00, 10, 00, '+00:00')
    visit.time_window_end_1 = Time.new(2000, 01, 01, 00, 11, 00, '+00:00')
    visit.time_window_start_2 = Time.new(2000, 01, 01, 00, 10, 00, '+00:00')
    assert !destination.save

    visit.time_window_start_1 = Time.new(2000, 01, 01, 00, 10, 00, '+00:00')
    visit.time_window_end_1 = Time.new(2000, 01, 01, 00, 11, 00, '+00:00')
    visit.time_window_start_1 = Time.new(2000, 01, 01, 00, 12, 00, '+00:00')
    visit.time_window_end_2 = Time.new(2000, 01, 01, 00, 11, 00, '+00:00')
    assert !destination.save
  end

  test 'should support localized number separator' do
    orig_locale = I18n.locale
    visit = visits :visit_one

    begin
      I18n.locale = :en
      assert I18n.locale == :en
      assert_not_nil Visit.localize_numeric_value(nil)
      visit.update! quantities: {1 => nil}
      assert visit.localized_quantities[1].nil? # Don't crash with nil values
      visit.update! quantities: {1 => '10.5'} # Assign with localized separator
      assert_equal 10.5, visit.quantities[1]
      assert_equal '10.5', visit.localized_quantities[1] # Localized value
      visit.update! quantities: {1 => 10}
      assert_equal 10, visit.quantities[1]
      assert_equal '10', visit.localized_quantities[1] # Remove trailing zeros
      visit.update! quantities: {1 => 10.1} # Assign without localized separator
      assert_equal 10.1, visit.quantities[1]
      assert_not_nil Visit.localize_numeric_value(nil)

      I18n.locale = :fr
      assert I18n.locale == :fr
      assert_not_nil Visit.localize_numeric_value(nil)
      visit.update! quantities: {1 => nil}
      assert visit.localized_quantities[1].nil? # Don't crash with nil values
      visit.update! quantities: {1 => '10,5'} # Assign with localized separator
      assert_equal 10.5, visit.quantities[1]
      assert_equal '10,5', visit.localized_quantities[1] # Localized value
      visit.update! quantities: {1 => 10}
      assert_equal 10, visit.quantities[1]
      assert_equal '10', visit.localized_quantities[1] # Remove trailing zeros
      visit.update! quantities: {1 => 10.1} # Assign without localized separator
      assert_equal 10.1, visit.quantities[1]
    ensure
      I18n.locale = orig_locale
    end
  end

  test 'should return color and icon' do
    visit = visits :visit_one
    tag1 = tags :tag_one

    assert_equal tag1.color, visit.color
    assert_nil visit.icon
  end

  test 'should check priority value' do
    visit = visits :visit_two
    assert_nil visit.priority

    assert_not visit.update(priority: 10)
    assert visit.update(priority: 0)
  end

  test 'should not changed with same attributes' do
    visit = visits :visit_one

    visit.assign_attributes(visit.attributes)
    assert_not visit.changed?, visit.attributes.keys.select{ |k| visit.send("#{k}_changed?") }.map{ |k| "#{k} has changed" }.join(', ')

    visit.assign_attributes(quantities_operations: {})
    assert_not visit.changed?, visit.attributes.keys.select{ |k| visit.send("#{k}_changed?") }.map{ |k| "#{k} has changed" }.join(', ')
  end

  test 'should return error if quantity is invalid' do
    visit = visits(:visit_one)

    visit.quantities = {customers(:customer_one).deliverable_units[0].id => '12,3'}
    assert visit.save

    visit.quantities = {customers(:customer_one).deliverable_units[0].id => 'not a float'}
    assert_not visit.save
    assert_equal visit.errors.first.message, I18n.t('activerecord.errors.models.visit.attributes.quantities.not_float')
  end

  test 'should update outdated for quantity' do
    visit = visits :visit_one
    assert_not visit.stop_visits[-1].route.outdated
    visit.quantities = {customers(:customer_one).deliverable_units[0].id => '12,3'}
    visit.save!
    assert visit.stop_visits[-1].route.reload.outdated # Reload route because it not updated in main scope
    assert_equal 12.3, Visit.find(visit.id).quantities[customers(:customer_one).deliverable_units[0].id]
  end

  test 'should update outdated for empty quantity' do
    visit = visits :visit_two
    assert_not visit.stop_visits[-1].route.outdated
    visit.quantities = {}
    visit.save!
    assert visit.stop_visits[-1].route.reload.outdated # Reload route because it not updated in main scope
    assert_nil Visit.find(visit.id).quantities[customers(:customer_one).deliverable_units[0].id]
  end

  test 'should accept negative quantity' do
    visit = visits :visit_three
    assert_not visit.stop_visits[-1].route.outdated
    visit.quantities = {customers(:customer_one).deliverable_units[0].id => '-12,3'}
    visit.save!
    assert visit.stop_visits[-1].route.reload.outdated # Reload route because it not updated in main scope
    assert_equal -12.3, Visit.find(visit.id).quantities[customers(:customer_one).deliverable_units[0].id]
  end

  test 'should set quantity to 0 if fill/empty' do
    visit = visits :visit_one
    assert_not visit.stop_visits[-1].route.outdated
    visit.quantities = {customers(:customer_one).deliverable_units[0].id => nil}
    visit.quantities_operations = {customers(:customer_one).deliverable_units[0].id => 'empty'}
    visit.save!
    assert visit.stop_visits[-1].route.reload.outdated # Reload route because it not updated in main scope
    assert_equal 0, Visit.find(visit.id).quantities[customers(:customer_one).deliverable_units[0].id]
  end

  test 'should outdate route after tag changed' do
    route = routes(:route_zero_one)
    destinations(:destination_unaffected_one).update tags: []
    route.update outdated: false # TODO: temporary, until tag changed not update outdated

    without_loading Stop, if: -> (obj) { obj.route_id != route.id && obj.route_id != routes(:route_zero_two).id } do
      assert !route.outdated
      visits(:visit_unaffected_one).update tags: [tags(:tag_two)]
      assert route.reload.outdated
    end
  end

  test 'time_window_end_2 should not be after time_window_start_2' do
    visit = visits(:visit_one)

    assert_raises ActiveRecord::RecordInvalid do
      visit.update! time_window_end_2: '09:00', time_window_start_2: '10:00'
    end
  end

  test 'position should be in the existing values' do
    destination = destinations(:destination_one)
    visit = destination.visits[0]
    assert visit.neutral?
    visit.update force_position: 'always_first'
    assert visit.always_first?
    visit.update force_position: :always_final
    assert visit.always_final?
    visit.update force_position: 'never_first'
    assert visit.never_first?

    assert_raises ArgumentError do
      visit.update force_position: 'invalid_value'
    end
  end

  test 'should format quantities in attributes' do
    visit = visits(:visit_one)
    customer = visit.destination.customer

    du1 = customer.deliverable_units.create!(label: 'Unit 1')
    du2 = customer.deliverable_units.create!(label: 'Unit 2')

    visit.quantities = { du1.id => 10, du2.id => 20 }
    visit.quantities_operations = { du1.id => 'fill', du2.id => 'empty' }
    visit.save!

    attributes = visit.api_attributes
    quantities = attributes['quantities']

    assert_equal 2, quantities.size

    assert_equal du1.id, quantities[0][:deliverable_unit_id]
    assert_equal 10, quantities[0][:quantity]
    assert_equal 'fill', quantities[0][:operation]

    assert_equal du2.id, quantities[1][:deliverable_unit_id]
    assert_equal(-20, quantities[1][:quantity])
    assert_equal 'empty', quantities[1][:operation]
  end

  test 'should validate revenue as float' do
    @visit.revenue = 100.50
    assert @visit.valid?

    @visit.revenue = '100,50'
    assert @visit.valid?

    @visit.revenue = 'not a float'
    assert_not @visit.valid?

    @visit.revenue = nil
    assert @visit.valid?
  end

  test 'should accept integer values for revenue' do
    @visit.revenue = 100
    assert @visit.valid?
  end

  test 'should accept zero values for revenue' do
    @visit.revenue = 0
    assert @visit.valid?
  end

  test 'should reject negative values for revenue' do
    @visit.revenue = -100.50
    assert_not @visit.valid?
  end
end
