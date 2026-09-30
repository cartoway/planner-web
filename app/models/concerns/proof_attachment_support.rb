# frozen_string_literal: true

# Signing, purge and validation helpers for ProofAttachments.
module ProofAttachmentSupport
  extend ActiveSupport::Concern

  class_methods do
    def photo_verifier
      Rails.application.message_verifier('stop_photos')
    end

    def find_photo_blob!(signed_id)
      blob_id = photo_verifier.verify(signed_id, purpose: ProofAttachments::PHOTO_SIGNED_ID_PURPOSE)
      ActiveStorage::Blob.find(blob_id)
    end

    def photo_host_from_env(env)
      return unless env

      host = env['HTTP_HOST']
      return unless host

      scheme = env['HTTPS'] == 'on' || env['rack.url_scheme'] == 'https' ? 'https' : 'http'
      "#{scheme}://#{host}"
    end

    def signature_verifier
      Rails.application.message_verifier('stop_signatures')
    end

    def find_signature_blob!(signed_id)
      blob_id = signature_verifier.verify(signed_id, purpose: ProofAttachments::SIGNATURE_SIGNED_ID_PURPOSE)
      ActiveStorage::Blob.find(blob_id)
    end
  end

  private

  def purge_signature_blob!
    attachment = signature_attachment
    return unless attachment

    blob = attachment.blob
    ActiveStorage::Attachment.delete(attachment.id)
    key = blob.key
    service = blob.service
    ActiveStorage::Blob.delete(blob.id)
    service.delete(key)
    association(:signature_attachment).reset
    association(:signature_blob).reset
  end

  def signature_signed_url(blob, host: nil)
    signed_id = self.class.signature_verifier.generate(
      blob.id,
      expires_in: ProofAttachments::SIGNATURE_URL_EXPIRES_IN,
      purpose: ProofAttachments::SIGNATURE_SIGNED_ID_PURPOSE
    )
    if host.present?
      uri = URI.parse(host)
      Rails.application.routes.url_helpers.signed_stop_signature_url(
        signed_id,
        host: uri.host,
        port: uri.port,
        protocol: uri.scheme || 'http'
      )
    else
      Rails.application.routes.url_helpers.signed_stop_signature_path(signed_id)
    end
  end

  def signature_attachable?(file)
    if file.blank?
      errors.add(:signature, :blank)
      return false
    end
    unless ProofAttachments::SIGNATURE_CONTENT_TYPES.include?(file.content_type)
      errors.add(:signature, :invalid_type)
      return false
    end
    if file.size > ProofAttachments::SIGNATURE_MAX_BYTE_SIZE
      errors.add(:signature, :too_large)
      return false
    end
    true
  end

  def signature_must_be_valid_image
    unless ProofAttachments::SIGNATURE_CONTENT_TYPES.include?(signature.content_type)
      errors.add(:signature, :invalid_type)
    end
    if signature.byte_size > ProofAttachments::SIGNATURE_MAX_BYTE_SIZE
      errors.add(:signature, :too_large)
    end
  end

  def photo_signed_url(blob, host: nil)
    signed_id = self.class.photo_verifier.generate(
      blob.id,
      expires_in: ProofAttachments::PHOTO_URL_EXPIRES_IN,
      purpose: ProofAttachments::PHOTO_SIGNED_ID_PURPOSE
    )
    if host.present?
      uri = URI.parse(host)
      Rails.application.routes.url_helpers.signed_stop_photo_url(
        signed_id,
        host: uri.host,
        port: uri.port,
        protocol: uri.scheme || 'http'
      )
    else
      Rails.application.routes.url_helpers.signed_stop_photo_path(signed_id)
    end
  end

  def photos_attachable?(files)
    if files.empty?
      errors.add(:photos, :blank)
      return false
    end
    if photos.count + files.size > ProofAttachments::PHOTO_MAX_COUNT
      errors.add(:photos, :too_many)
      return false
    end
    files.each do |file|
      unless ProofAttachments::PHOTO_CONTENT_TYPES.include?(file.content_type)
        errors.add(:photos, :invalid_type)
        return false
      end
      if file.size > ProofAttachments::PHOTO_MAX_BYTE_SIZE
        errors.add(:photos, :too_large)
        return false
      end
    end
    true
  end

  def photos_must_be_valid_images
    if photos.count > ProofAttachments::PHOTO_MAX_COUNT
      errors.add(:photos, :too_many)
    end
    photos.each do |photo|
      unless ProofAttachments::PHOTO_CONTENT_TYPES.include?(photo.content_type)
        errors.add(:photos, :invalid_type)
      end
      if photo.byte_size > ProofAttachments::PHOTO_MAX_BYTE_SIZE
        errors.add(:photos, :too_large)
      end
    end
  end
end
