require "ipaddr"

class Lookup < ApplicationRecord
  # Accepted on input: 12 hex digits, or six octets separated consistently by colons or hyphens.
  MAC_FORMAT = /\A(?:[0-9a-fA-F]{12}|(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}|(?:[0-9a-fA-F]{2}-){5}[0-9a-fA-F]{2})\z/
  # Stored and sent to the vendor provider: uppercase, colon separated.
  NORMALIZED_FORMAT = /\A(?:[0-9A-F]{2}:){5}[0-9A-F]{2}\z/
  STATUSES = %w[resolved unknown failed].freeze

  before_validation :normalize_mac
  validates :mac, presence: true,
    format: { with: NORMALIZED_FORMAT, message: "must be six hexadecimal octets using colons, hyphens, or no separators" }
  validates :status, inclusion: { in: STATUSES }
  validates :vendor, length: { maximum: 255 }, allow_nil: true
  validate :valid_ipv4
  validate :vendor_matches_status

  def api_attributes
    { id: id, ip: ip, mac: mac, vendor: vendor, status: status, created_at: created_at.utc.iso8601(3) }
  end

  private

  # Anything that is not a recognized MAC string is left as-is for the format validation to reject.
  def normalize_mac
    value = mac_before_type_cast
    return unless value.is_a?(String) && value.match?(MAC_FORMAT)
    self.mac = value.delete(":-").upcase.scan(/../).join(":")
  end

  def valid_ipv4
    value = ip_before_type_cast
    return if value.nil?
    valid = value.is_a?(String) && value.match?(/\A(?:\d{1,3}\.){3}\d{1,3}\z/) && IPAddr.new(value).ipv4?
    errors.add(:ip, "must be an IPv4 address") unless valid
  rescue IPAddr::InvalidAddressError
    errors.add(:ip, "must be an IPv4 address")
  end

  def vendor_matches_status
    if status == "resolved"
      errors.add(:vendor, "must be present for a resolved lookup") if vendor.blank?
    elsif vendor.present?
      errors.add(:vendor, "must be absent for an unknown or failed lookup")
    end
  end
end
