require 'rails_helper'
require 'capybara_helper'

feature :planning do
  fixtures :all

  before :each do
    login
  end

  scenario 'add', js: true do
    # Create planning
    visit new_planning_path
    fill_in 'planning[name]', with: 'P'
    find('.select2-container input').set('tag1')
    find('li.select2-result:first-child').click
    submit

    expect(page).to have_selector('.alert-success')

    assert_equal 'P', find_field('planning[name]').value
    within(:css, '.select2-choices') do
      assert_text('tag1')
    end

    first('.route')
    expect(page).to have_selector('.route', count: 2)
    expect(page).to have_selector('.route:nth-child(1) .stops li', count: 3)
    expect(page).to have_selector('.route:nth-child(2) .stops li', count: 2)
  end

  scenario 'edit', js: true do
    # Open planning
    visit plannings_path
    expect(page).to_not have_selector('#refresh')
    find('tr', text: 'planning1').find('.fa-edit').click

    # Edit destination
    find('.route:nth-child(2) .stops li:nth-child(2) a:nth-child(1)').click
    first '[data-controller=destinations]'
    expect(page).to have_selector('[data-controller=destinations]')
    fill_in 'destination[city]', with: 'Brest'
    submit

    # Back
    expect(page).to have_selector('[data-controller=plannings]')

    # Check out of date
    expect(page).to have_selector('#refresh')
    find('#refresh').click
    sleep 1
    expect(page).to_not have_selector('#refresh')

    # Edit zoning
    find('#zoning_edit').click
    find('.zone:last-child .delete').click
    submit

    # Back
    expect(page).to have_selector('[data-controller=plannings]')

    # Check out of date
    expect(page).to have_selector('#refresh')
    find('#refresh').click
    sleep 1
    expect(page).to_not have_selector('#refresh')
  end

  scenario 'automatic insert', js: true do
    # Open planning
    visit plannings_path
    expect(page).to_not have_selector('#refresh')
    find('tr', text: 'planning1').find('.fa-edit').click

    # Automatic insert
    expect(page).to have_selector('.route:nth-child(1) .stops li', count: 1)
    expect(page).to have_selector('.route:nth-child(2) .stops li', count: 4)
    find('.route:nth-child(1) .stops li:nth-child(1) button:nth-child(1)').click
    expect(page).to have_selector('.route:nth-child(1) .stops li', count: 0)
    expect(page).to have_selector('.route:nth-child(2) .stops li', count: 5)
  end
end
