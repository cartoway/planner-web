# frozen_string_literal: true

require 'job'
require 'import_csv'
require 'import_json'
require 'import_tomtom'
require 'importer_destinations'

ImporterDestinationsJobStruct ||= Job.new(:customer_id, :source, :blob_id, :options)
class ImporterDestinationsJob < ImporterDestinationsJobStruct
  def perform
    Delayed::Worker.logger.info('ImporterDestinationsJob perform', customer_id: customer_id, source: source)
    job_progress_save(
      'status' => 'working',
      'phase' => 'starting',
      'first_progression' => 0,
      'completed' => false
    )

    customer = Customer.find(customer_id)
    opts = (options || {}).with_indifferent_access
    planning_attrs = build_planning_attrs(customer, opts[:planning])
    importer = ImporterDestinations.new(customer, planning_attrs)
    importer.progress_callback = ->(progress) { job_progress_save(progress) }
    import = build_import(customer, importer, opts)

    result = import.import(false)
    unless result
      message = Array(import.errors.full_messages).join(', ').presence || 'Import failed'
      raise ImportBaseError, message
    end

    job_progress_save('status' => 'working', 'phase' => 'done', 'first_progression' => 100, 'completed' => true)
    result
  ensure
    purge_blob!
  end

  def max_attempts
    1
  end

  def destroy_failed_jobs?
    true
  end

  private

  def build_planning_attrs(customer, planning_opts)
    return {} if planning_opts.blank?

    planning = planning_opts.with_indifferent_access
    attrs = planning.slice(:name, :ref, :date).compact
    attrs[:vehicle_usage_set] = customer.vehicle_usage_sets.find(planning[:vehicle_usage_set_id]) if planning[:vehicle_usage_set_id].present?
    attrs[:zonings] = customer.zonings.find(planning[:zoning_ids]) if planning[:zoning_ids].present?
    attrs
  end

  def build_import(customer, importer, opts)
    case source.to_s
    when 'csv'
      ImportCsv.new(
        importer: importer,
        replace: opts[:replace],
        delete_plannings: opts[:delete_plannings],
        column_def: opts[:column_def],
        content_code: opts[:content_code],
        file: file_from_blob
      )
    when 'json'
      ImportJson.new(
        importer: importer,
        replace: opts[:replace],
        json: json_from_blob
      )
    when 'tomtom'
      ImportTomtom.new(
        importer: importer,
        customer: customer,
        replace: opts[:replace],
        content_code: opts[:content_code]
      )
    else
      raise ArgumentError, "Unknown import source: #{source}"
    end
  end

  def file_from_blob
    blob = ActiveStorage::Blob.find(blob_id)
    tempfile = Tempfile.new(['destinations_import', File.extname(blob.filename.to_s)])
    tempfile.binmode
    blob.download { |chunk| tempfile.write(chunk) }
    tempfile.rewind
    ActionDispatch::Http::UploadedFile.new(
      tempfile: tempfile,
      filename: blob.filename.to_s,
      type: blob.content_type
    )
  end

  def json_from_blob
    blob = ActiveStorage::Blob.find(blob_id)
    JSON.parse(blob.download, symbolize_names: true)
  end

  def purge_blob!
    return if blob_id.blank?

    ActiveStorage::Blob.find_by(id: blob_id)&.purge
  rescue StandardError => e
    Delayed::Worker.logger.warn("ImporterDestinationsJob blob purge failed: #{e.message}")
  end
end
