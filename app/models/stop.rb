# Copyright © Mapotempo, 2013-2017
#
# This file is part of Mapotempo.
#
# Mapotempo is free software. You can redistribute it and/or
# modify since you respect the terms of the GNU Affero General
# Public License as published by the Free Software Foundation,
# either version 3 of the License, or (at your option) any later version.
#
# Mapotempo is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
# or FITNESS FOR A PARTICULAR PURPOSE.  See the Licenses for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with Mapotempo. If not, see:
# <http://www.gnu.org/licenses/agpl.html>
#
class Stop < ApplicationRecord
  default_scope { order(:index) }

  belongs_to :route, touch: true
  belongs_to :route_data, optional: true
  belongs_to :visit, optional: true # TODO: Remove optional
  belongs_to :store, optional: true
  belongs_to :store_reload, optional: true

  nilify_blanks

  include LocalizedAttr
  attr_localized :loads

  include QuantityAttr
  quantity_attr :loads

  include TimeAttr
  attribute :time, ScheduleType.new
  time_attr :time

  include TypedAttribute
  typed_attr :custom_attributes

  has_many_attached :photos
  has_one_attached :signature

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
  DELIVERY_NOTE_STATUSES = %w[delivered exception].freeze

  validates :route, presence: true
  validate :photos_must_be_valid_images, if: -> { photos.attached? }
  validate :signature_must_be_valid_image, if: -> { signature.attached? }

  scope :only_stop_visits, -> { where(type: StopVisit.name) }
  scope :only_stop_stores, -> { where(type: StopStore.name) }
  scope :only_active, -> { where(active: true) }
  scope :only_active_stop_visits, -> { only_stop_visits.where(active: true) }
  scope :includes_destinations_and_stores, -> {
    with_attached_photos.with_attached_signature.includes(
      :route_data,
      visit: [
        :tags,
        destination: [
          :visits,
          :tags,
          { customer: :deliverable_units }
        ]
      ],
      store_reload: [:store],
      store: [:customer]
    )
  }
  scope :includes_relations, -> { includes(visit: [:relation_currents, :relation_successors])}
  scope :includes_route_details, -> {
    includes(route: [
      :route_data, :start_route_data, :stop_route_data, :planning,
      { vehicle_usage: :vehicle }
    ])
  }
  scope :by_route_then_index, -> { reorder(:route_id, :index) }

  before_save :outdate_route
  before_save :reject_writes_during_optimization
  before_destroy :reject_writes_during_optimization

  # Return best fit time window, and late (positive) time or waiting time (negative).
  # When strict_within_timewindows is true, the close side compares service end (arrival + duration)
  # to the window end, matching optimization (visit must finish by time_window_end).
  def best_open_close(time, strict_within_timewindows: false)
    close_compare_time = strict_within_timewindows && time ? time + duration : time
    [[time_window_start_1, time_window_end_1], [time_window_start_2, time_window_end_2]].select{ |open, close|
      open || close
    }.collect{ |open, close|
      [open, close, eval_open_close(open, close, time, close_compare_time)]
    }.min_by{ |_open, _close, eval|
      eval.abs
    }
  end

  def number(inactive_stop)
    if self.active && self.route.vehicle_usage_id
      self.index - inactive_stop
    else
      nil
    end
  end

  def default_color
    (self.visit && visit.color) || route.default_color
  end

  def delivery_note_available?
    is_a?(StopVisit) && DELIVERY_NOTE_STATUSES.include?(status&.downcase)
  end

  def outdate_route
    if active_changed? && !new_record?
      route.outdated = true if route
    end
  end

  def reject_writes_during_optimization
    route&.planning&.reject_writes_during_optimization!
  end

  def optim_type
    'default'
  end

  def attach_photos(files)
    files = Array.wrap(files).compact
    return unless photos_attachable?(files)

    # Insert attachments without touching the stop (STI + lock_version).
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
  # App serving still uses Postgres blob id + signed URL; prefixes help LIST/purge/lifecycle.
  def photo_storage_key
    customer_id = route&.planning&.customer_id || 'unknown'
    day = Time.current.utc.strftime('%Y/%m/%d')
    token = ActiveStorage::Blob.generate_unique_secure_token
    "customers/#{customer_id}/#{day}/#{token}"
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

  def self.photo_verifier
    Rails.application.message_verifier('stop_photos')
  end

  def self.find_photo_blob!(signed_id)
    blob_id = photo_verifier.verify(signed_id, purpose: PHOTO_SIGNED_ID_PURPOSE)
    ActiveStorage::Blob.find(blob_id)
  end

  def self.photo_host_from_env(env)
    return unless env

    host = env['HTTP_HOST']
    return unless host

    scheme = env['HTTPS'] == 'on' || env['rack.url_scheme'] == 'https' ? 'https' : 'http'
    "#{scheme}://#{host}"
  end

  def attach_signature(file)
    return unless signature_attachable?(file)

    # Replace existing signature without touching the stop (STI + lock_version).
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

  def self.signature_verifier
    Rails.application.message_verifier('stop_signatures')
  end

  def self.find_signature_blob!(signed_id)
    blob_id = signature_verifier.verify(signed_id, purpose: SIGNATURE_SIGNED_ID_PURPOSE)
    ActiveStorage::Blob.find(blob_id)
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
    signed_id = self.class.signature_verifier.generate(blob.id, expires_in: SIGNATURE_URL_EXPIRES_IN, purpose: SIGNATURE_SIGNED_ID_PURPOSE)
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
    unless SIGNATURE_CONTENT_TYPES.include?(file.content_type)
      errors.add(:signature, :invalid_type)
      return false
    end
    if file.size > SIGNATURE_MAX_BYTE_SIZE
      errors.add(:signature, :too_large)
      return false
    end
    true
  end

  def signature_must_be_valid_image
    unless SIGNATURE_CONTENT_TYPES.include?(signature.content_type)
      errors.add(:signature, :invalid_type)
    end
    if signature.byte_size > SIGNATURE_MAX_BYTE_SIZE
      errors.add(:signature, :too_large)
    end
  end

  def photo_signed_url(blob, host: nil)
    signed_id = self.class.photo_verifier.generate(blob.id, expires_in: PHOTO_URL_EXPIRES_IN, purpose: PHOTO_SIGNED_ID_PURPOSE)
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
    if photos.count + files.size > PHOTO_MAX_COUNT
      errors.add(:photos, :too_many)
      return false
    end
    files.each do |file|
      unless PHOTO_CONTENT_TYPES.include?(file.content_type)
        errors.add(:photos, :invalid_type)
        return false
      end
      if file.size > PHOTO_MAX_BYTE_SIZE
        errors.add(:photos, :too_large)
        return false
      end
    end
    true
  end

  def photos_must_be_valid_images
    if photos.count > PHOTO_MAX_COUNT
      errors.add(:photos, :too_many)
    end
    photos.each do |photo|
      unless PHOTO_CONTENT_TYPES.include?(photo.content_type)
        errors.add(:photos, :invalid_type)
      end
      if photo.byte_size > PHOTO_MAX_BYTE_SIZE
        errors.add(:photos, :too_large)
      end
    end
  end

  def eval_open_close(open, close, time, close_compare_time = time)
    if open && time < open
      time - open # Negative
    elsif close && close_compare_time > close
      soft_upper_bound = self.route.planning.customer.optimization_stop_soft_upper_bound || Planner::Application.config.optimize_stop_soft_upper_bound
      if soft_upper_bound > 0
        (close_compare_time - close) * soft_upper_bound # Positive
      else
        2**31 # Strict
      end
    else
      0
    end
  end

end
