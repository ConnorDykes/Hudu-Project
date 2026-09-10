require "date"
require "time"

class ProcessEvent < ApplicationRecord
  UUID_FORMAT = /\A[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}\z/
  TIMESTAMP_FORMAT = /\A\d{4}-\d{2}-\d{2}T(?:[01]\d|2[0-3]):[0-5]\d:[0-5]\d(?:\.\d{1,6})?(?:Z|[+-](?:[01]\d|2[0-3]):[0-5]\d)\z/

  before_validation :normalize_event_id
  before_validation :normalize_occurrence
  validates :event_id, presence: true, format: { with: UUID_FORMAT }
  validates :process_name, presence: true, length: { maximum: 255 }
  validates :occurred_at, presence: true
  validate :name_is_string
  validate :pid_is_positive_integer

  def same_payload?(other)
    process_name == other.process_name && pid == other.pid && occurred_at == other.occurred_at
  end

  def api_attributes
    {
      id: id, event_id: event_id, process_name: process_name, pid: pid,
      occurred_at: occurred_at.utc.iso8601(3), created_at: created_at.utc.iso8601(3)
    }
  end

  private

  def normalize_event_id
    self.event_id = event_id.downcase if event_id_before_type_cast.is_a?(String)
  end

  def normalize_occurrence
    value = occurred_at_before_type_cast
    return if value.is_a?(Time) || value.is_a?(ActiveSupport::TimeWithZone)
    if value.is_a?(String) && value.match?(TIMESTAMP_FORMAT)
      Date.iso8601(value.split("T").first)
      self.occurred_at = Time.iso8601(value).utc
    else
      errors.add(:occurred_at, "must be an ISO 8601 timestamp with a timezone and at most six fractional digits")
    end
  rescue ArgumentError
    errors.add(:occurred_at, "must be a valid ISO 8601 timestamp")
  end

  def name_is_string
    errors.add(:process_name, "must be a string") unless process_name_before_type_cast.is_a?(String)
  end

  def pid_is_positive_integer
    value = pid_before_type_cast
    unless value.is_a?(Integer) && (1..9_223_372_036_854_775_807).cover?(value)
      errors.add(:pid, "must be a positive integer within the database integer range")
    end
  end
end
