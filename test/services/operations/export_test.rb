# frozen_string_literal: true

require 'test_helper'
require 'zip'

class OperationsExportTest < ActiveSupport::TestCase
  setup do
    @planning = plannings(:planning_one)
    @operation = Operations::PublishFromPlanning.call(planning: @planning)
    @stop = @operation.operation_stops.find_by!(stop_id: stops(:stop_one_one).id)
    @stop.update_columns(status: 'delivered', status_updated_at: Time.zone.parse('2026-09-25 11:00'))
    file = Rack::Test::UploadedFile.new(Rails.root.join('test/fixtures/files/stop_photo.jpg'), 'image/jpeg')
    assert @stop.attach_photos([file])
    file.rewind if file.respond_to?(:rewind)
    assert @stop.attach_signature(file)
  end

  teardown do
    @stop&.photos&.purge
    @stop&.signature&.purge if @stop&.signature&.attached?
    Operation.where(customer_id: @planning.customer_id).delete_all
  end

  test 'board from preloaded export routes stays on snapshots' do
    routes = @operation.operation_routes.includes_for_export.order(:index, :id).to_a
    queries = []
    counter = ->(*, payload) { queries << payload[:sql] }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      board = @operation.board(routes: routes)
      assert board.key?(:delivered)
      assert board.key?(:plan)
    end
    assert queries.none? { |sql| sql.match?(/FROM ["`]?routes["`]?/i) }, queries.join("\n")
    assert queries.none? { |sql| sql.match?(/FROM ["`]?route_data["`]?/i) }, queries.join("\n")
  end

  test 'export preload skips live planning graph' do
    queries = []
    counter = ->(*, payload) { queries << payload[:sql] unless payload[:name] == 'SCHEMA' }
    ActiveSupport::Notifications.subscribed(counter, 'sql.active_record') do
      Operations::DeliveryNotePdf.stubs(:call).returns("%PDF-1.4\n%%EOF\n")
      Operations::Export.new(@operation).to_zip
    end
    joined = queries.join("\n")
    assert queries.none? { |sql| sql.match?(/FROM ["`]?visits["`]?/i) }, joined
    assert queries.none? { |sql| sql.match?(/FROM ["`]?destinations["`]?/i) }, joined
    assert queries.none? { |sql| sql.match?(/FROM ["`]?stops["`]?/i) }, joined
    assert queries.none? { |sql| sql.match?(/FROM ["`]?routes["`]?/i) }, joined
    assert queries.none? { |sql| sql.match?(/FROM ["`]?route_data["`]?/i) }, joined
    assert queries.none? { |sql| sql.match?(/FROM ["`]?plannings["`]?/i) }, joined
  end

  test 'csv includes operation route and stop columns' do
    csv = Operations::Export.new(@operation).to_csv
    header, *rows = CSV.parse(csv)
    status_idx = header.index('stop_status')
    row = rows.find { |cells| cells[status_idx] == 'delivered' }

    assert_includes header, 'operation_name'
    assert_includes header, 'vehicle_name'
    assert_includes header, 'stop_status'
    assert_includes header, 'operation_delivered'
    assert_includes header, 'planned_arrival'
    assert_includes header, 'delay_minutes'
    assert row, 'expected a CSV row for the delivered stop'
    assert_equal @operation.name, row[header.index('operation_name')]
    assert_equal @stop.index.to_s, row[header.index('stop_index')]
  end

  test 'zip includes html csv media delivery note pdf tracks and carousel' do
    route = @stop.operation_route
    route.update_columns(
      route_snapshot: (route.route_snapshot || {}).merge(
        'tracks' => [{ 'coordinates' => [[2.0, 48.0], [2.1, 48.1]] }]
      )
    )
    Operations::DeliveryNotePdf.stubs(:call).returns("%PDF-1.4\n% export fixture\n%%EOF\n")

    zip_io = Operations::Export.new(@operation.reload).to_zip
    entries = zip_entries(zip_io)

    assert_includes entries.keys, 'index.html'
    assert_includes entries.keys, 'stops.csv'
    assert entries.keys.any? { |name| name.start_with?("media/route_#{route.id}/stop_#{@stop.id}/photos/") }
    assert entries.keys.any? { |name| name.start_with?("media/route_#{route.id}/stop_#{@stop.id}/signature") }
    assert_includes entries.keys, "delivery_notes/stop_#{@stop.id}.pdf"
    assert_includes entries.keys, "tracks/route_#{route.id}.geojson"
    html = entries['index.html'].force_encoding('UTF-8')
    assert_includes html, @operation.name
    assert_includes html, 'data-proof-carousel'
    assert_includes html, 'data-proof-lightbox'
    assert_includes html, I18n.t('operations.show.cumulative_delay')
    assert_operator entries["delivery_notes/stop_#{@stop.id}.pdf"], :start_with?, '%PDF'
    assert_includes entries["tracks/route_#{route.id}.geojson"], 'LineString'
  end

  test 'zip skips delivery notes when none exportable' do
    @operation.operation_stops.update_all(status: 'pending')
    Operations::DeliveryNotePdf.expects(:call).never

    entries = zip_entries(Operations::Export.new(@operation.reload).to_zip)
    assert_includes entries.keys, 'index.html'
    assert_includes entries.keys, 'stops.csv'
    assert entries.keys.none? { |name| name.start_with?('delivery_notes/') }
  end

  test 'delivery note remains exportable without live stop_id' do
    @stop.update_columns(stop_id: nil)
    assert @stop.delivery_note_exportable?
    assert_not @stop.delivery_note_available?
    Operations::DeliveryNotePdf.stubs(:call).returns("%PDF-1.4\n%%EOF\n")

    entries = zip_entries(Operations::Export.new(@operation).to_zip)
    assert_includes entries.keys, "delivery_notes/stop_#{@stop.id}.pdf"
  end

  test 'zip writes one pdf file per delivery note' do
    visits = @operation.operation_stops.select(&:visit?).first(2)
    assert_operator visits.size, :>=, 2
    visits.each { |stop| stop.update_columns(status: 'delivered') }

    Operations::DeliveryNotePdf.stubs(:call).returns("%PDF-1.4\n%%EOF\n")
    entries = zip_entries(Operations::Export.new(@operation.reload).to_zip)
    visits.each do |stop|
      assert_includes entries.keys, "delivery_notes/stop_#{stop.id}.pdf"
    end
    assert entries.keys.none? { |name| name == 'delivery_notes/delivery_notes.pdf' }
  end

  test 'delivery note html uses the same template as operation stop print' do
    html = Operations::DeliveryNotePdf.new(@stop).html
    assert_includes html, 'delivery-note'
    assert_includes html, 'delivery-note-items'
    assert_includes html, 'delivery-note-signature'
    assert_includes html, 'btn-print'
    assert_includes html, I18n.t('stops.delivery_note.title')
    assert_includes html, File.read(Rails.root.join('app/assets/stylesheets/v2/delivery_note_pdf.css')).lines.grep(/delivery-note-items thead/).first.to_s.strip

    ui = ApplicationController.render(
      template: 'stops/delivery_note',
      layout: 'operations/export_delivery_note',
      assigns: Operations::DeliveryNoteDocument.assigns(@stop, embed_logo: true, snapshots_only: true)
    )
    assert_equal ui, html
  end

  test 'export delivery note pdf uses snapshots only' do
    pdf = Operations::DeliveryNoteDocument.assigns(@stop, embed_logo: true, snapshots_only: true)
    assert_kind_of Operations::DeliveryNoteDocument::SnapshotRecord, pdf[:stop]
    assert_kind_of Operations::DeliveryNoteDocument::SnapshotRecord, pdf[:destination]
    assert_nil pdf[:route]
    assert_nil pdf[:planning]
    assert_operator pdf[:photos].size, :>=, 1
    assert pdf[:signature]
  end

  test 'export delivery note pdf embeds proofs when present' do
    assigns = Operations::DeliveryNoteDocument.assigns(@stop, embed_logo: true, snapshots_only: true)
    assert_operator assigns[:photos].size, :>=, 1
    assert assigns[:signature]
  end

  private

  def zip_entries(zip_io)
    entries = {}
    Zip::InputStream.open(StringIO.new(zip_io.string)) do |io|
      while (entry = io.get_next_entry)
        entries[entry.name] = io.read
      end
    end
    entries
  end
end
