require 'rails_helper'

RSpec.describe ImportCsv, type: :model do
  context 'Destinations' do
    let(:importer) { ImporterDestinations.new(Customer.first) }

    describe 'should import destinations with empty lines' do
      before do
        I18n.default_locale = :fr
        I18n.locale = :fr
      end
      let(:file) { fixture_file_upload('import_destinations_with_empty_lines.csv') }
      let(:import_csv) { ImportCsv.new(file: file, importer: importer, content_code: :html, replace: false, delete_plannings: false) }
      it { expect(import_csv.valid?).to be_truthy }
      it { expect(import_csv.import.compact).to eq([{:ref=>:"C0007-1", :name=>"CARREFOUR PONTAULT-COMBAULT - FRA084 POUR LUSIFOOD", :street=>"RN4", :detail=>nil, :geocoding_result=>{}, :geocoding_accuracy=>nil, :geocoding_level=>1, :postalcode=>"77340", :city=>"PONTAULT-COMBAULT", :lat=>48.776156, :lng=>2.610715, :phone_number=>"164434720", :comment=>nil, :customer_id=>1}]) }
    end

    describe 'should import destinations in EN locales' do
      before do
        I18n.default_locale = :en
        I18n.locale = :en
      end
      let(:file) { fixture_file_upload('import_destinations_EN.csv') }
      let(:import_csv) { ImportCsv.new(file: file, importer: importer, content_code: :html, replace: false, delete_plannings: false) }

      it { expect(import_csv.valid?).to be_truthy }
      it { expect(import_csv.import).to eq([{:city=>"PARIS 12", :comment=>nil, :country=>nil, :customer_id=>1, :detail=>nil, :lat=>49.173419, :lng=>-0.326613, :name=>"LEPAGE JEONG", :phone_number=>"610549758", :postalcode=>"75012", :ref=>nil, :street=>"7ter Rue du Colonel Oudot"}]) }
    end
  end
end
