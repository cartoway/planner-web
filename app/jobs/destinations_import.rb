# frozen_string_literal: true

require 'importer_destinations_job'

class DestinationsImport
  class << self
    # source: 'csv' | 'json' | 'tomtom'
    # Returns Delayed::Job when enqueued, import result when run synchronously, false when refused.
    def enqueue(customer, source:, blob: nil, options: {}, synchronous: false)
      if customer.destination_import_running?
        customer.errors.add(:base, I18n.t('errors.destination.already_importing'))
        return false
      end

      customer.job_destination_import.destroy if customer.job_destination_import

      job = ImporterDestinationsJob.new(customer.id, source.to_s, blob&.id, options)
      if !synchronous && Planner::Application.config.delayed_job_use
        customer.job_destination_import = Delayed::Job.enqueue(job)
        customer.save!
        customer.job_destination_import
      else
        begin
          job.perform
        ensure
          blob&.purge
        end
      end
    end

    def persist_upload!(file)
      if file.is_a?(CSVFile)
        io = StringIO.new(file.content)
      else
        io = file.respond_to?(:tempfile) ? file.tempfile : file
        io.rewind if io.respond_to?(:rewind)
      end
      filename =
        if file.respond_to?(:original_filename) && file.original_filename.present?
          file.original_filename
        elsif file.respond_to?(:filename) && file.filename.present?
          file.filename
        else
          'import.csv'
        end
      content_type = file.respond_to?(:content_type) && file.content_type.present? ? file.content_type : 'text/csv'
      ActiveStorage::Blob.create_and_upload!(io: io, filename: filename, content_type: content_type)
    end

    def persist_json!(data)
      ActiveStorage::Blob.create_and_upload!(
        io: StringIO.new(JSON.generate(data.as_json)),
        filename: 'import.json',
        content_type: 'application/json'
      )
    end
  end
end
