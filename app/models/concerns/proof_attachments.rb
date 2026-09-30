# frozen_string_literal: true

module ProofAttachments
  extend ActiveSupport::Concern
  include ProofAttachmentSupport

  PHOTO_SIGNED_ID_PURPOSE = :stop_photo
  PHOTO_URL_EXPIRES_IN = 60.minutes
  PHOTO_DELETABLE_FOR = 1.hour
  PHOTO_MAX_COUNT = 10
  PHOTO_MAX_BYTE_SIZE = 10.megabytes
  PHOTO_CONTENT_TYPES = %w[image/jpeg image/png image/webp image/heic image/heif image/gif].freeze

  SIGNATURE_SIGNED_ID_PURPOSE = :stop_signature
  SIGNATURE_URL_EXPIRES_IN = 60.minutes
  SIGNATURE_MAX_BYTE_SIZE = 2.megabytes
  SIGNATURE_CONTENT_TYPES = %w[image/png image/jpeg image/webp].freeze

  included do
    validate :photos_must_be_valid_images, if: -> { photos.attached? }
    validate :signature_must_be_valid_image, if: -> { signature.attached? }
  end

  def attach_photos(files)
    files = Array.wrap(files).compact
    return unless photos_attachable?(files)

    # Insert attachments without touching the record (STI + lock_version).
    files.each do |file|
      io = file.respond_to?(:tempfile) ? file.tempfile : file
      io.rewind if io.respond_to?(:rewind)
      blob = ActiveStorage::Blob.create_and_upload!(
        key: photo_storage_key,
        io: io,
        filename: file.respond_to?(:original_filename) ? file.original_filename : File.basename(io.path),
        content_type: file.content_type
      )
      ActiveStorage::Attachment.insert!(
        {
          name: 'photos',
          record_type: self.class.base_class.name,
          record_id: id,
          blob_id: blob.id,
          created_at: Time.current
        }
      )
    end
    photos_attachments.reset
  end

  # RustFS/S3 key layout for ops at high volume (thousands/day):
  # customers/<customer_id>/<YYYY>/<MM>/<DD>/<token>
  def photo_storage_key
    customer_id = proof_customer_id || 'unknown'
    day = Time.current.utc.strftime('%Y/%m/%d')
    token = ActiveStorage::Blob.generate_unique_secure_token
    "customers/#{customer_id}/#{day}/#{token}"
  end

  def proof_customer_id
    route&.planning&.customer_id
  end

  def photo_deletable?(attachment)
    attachment.created_at.present? && attachment.created_at > PHOTO_DELETABLE_FOR.ago
  end

  def destroy_photo(attachment)
    return unless photo_deletable?(attachment)

    blob = attachment.blob
    ActiveStorage::Attachment.delete(attachment.id)
    key = blob.key
    service = blob.service
    ActiveStorage::Blob.delete(blob.id)
    service.delete(key)
    photos_attachments.reset
  end

  def serialized_photos(host: nil)
    photos.map { |photo|
      {
        id: photo.id,
        filename: photo.filename.to_s,
        content_type: photo.content_type,
        url: photo_signed_url(photo.blob, host: host),
        deletable: photo_deletable?(photo)
      }
    }
  end

  def attach_signature(file)
    return unless signature_attachable?(file)

    purge_signature_blob! if signature.attached?

    io = file.respond_to?(:tempfile) ? file.tempfile : file
    io.rewind if io.respond_to?(:rewind)
    blob = ActiveStorage::Blob.create_and_upload!(
      key: photo_storage_key,
      io: io,
      filename: file.respond_to?(:original_filename) ? file.original_filename : File.basename(io.path),
      content_type: file.content_type
    )
    ActiveStorage::Attachment.insert!(
      {
        name: 'signature',
        record_type: self.class.base_class.name,
        record_id: id,
        blob_id: blob.id,
        created_at: Time.current
      }
    )
    association(:signature_attachment).reset
    association(:signature_blob).reset
    true
  end

  def serialized_signature(host: nil)
    return nil unless signature.attached?

    {
      id: signature.id,
      filename: signature.filename.to_s,
      content_type: signature.content_type,
      url: signature_signed_url(signature.blob, host: host)
    }
  end
end
