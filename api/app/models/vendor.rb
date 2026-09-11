# A manufacturer keyed by its 24-bit OUI (the first three octets of a MAC).
# Seeded rows are a small offline subset of the IEEE registry; user rows are
# names people assign when neither the table nor the public service knows a MAC.
class Vendor < ApplicationRecord
  OUI_INPUT = /\A(?:[0-9a-fA-F]{6}|(?:[0-9a-fA-F]{2}[:-]){2}[0-9a-fA-F]{2})\z/
  OUI_FORMAT = /\A(?:[0-9A-F]{2}:){2}[0-9A-F]{2}\z/
  SOURCES = %w[seed user].freeze

  before_validation :normalize_oui
  validates :oui, presence: true, format: { with: OUI_FORMAT, message: "must be the first three octets of a MAC address" }
  validates :name, presence: true, length: { maximum: 255 }
  validates :source, inclusion: { in: SOURCES }
  validate :name_is_plain_text

  # Accepts a full MAC in any accepted form, or just the OUI.
  def self.oui_for(value)
    return nil unless value.is_a?(String)
    digits = value.delete(":-").upcase
    return nil unless digits.match?(/\A[0-9A-F]{6}(?:[0-9A-F]{6})?\z/)
    digits[0, 6].scan(/../).join(":")
  end

  def self.for_mac(mac)
    oui = oui_for(mac)
    oui && find_by(oui: oui)
  end

  def api_attributes
    { id: id, oui: oui, name: name, source: source, created_at: created_at.utc.iso8601(3) }
  end

  private

  def normalize_oui
    normalized = Vendor.oui_for(oui_before_type_cast)
    self.oui = normalized if normalized
  end

  def name_is_plain_text
    value = name_before_type_cast
    return errors.add(:name, "must be a string") unless value.is_a?(String)
    errors.add(:name, "must not contain control characters or angle brackets") if value.match?(/[[:cntrl:]<>]/)
  end
end
