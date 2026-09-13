class VendorsController < ApplicationController
  def index
    render_page(Vendor.order(:name, :id))
  end

  # POST /vendors {"mac":"02:11:22:33:44:55","name":"Lab sensor"}
  # Accepts a full MAC or a bare OUI; the vendor is stored by OUI.
  def create
    payload = permitted_payload(:mac, :oui, :name)
    vendor = Vendor.new(oui: payload[:mac] || payload[:oui], name: payload[:name], source: "user")
    vendor.validate!
    existing = Vendor.find_by(oui: vendor.oui)
    return render_exists(existing) if existing

    vendor.save!
    render json: { data: vendor.api_attributes }, status: :created
  rescue ActiveRecord::RecordNotUnique
    # The unique index also handles simultaneous registrations of one OUI.
    render_exists(Vendor.find_by!(oui: vendor.oui))
  end

  private

  def render_exists(existing)
    render_error(:conflict, "vendor_exists", "A vendor is already registered for #{existing.oui}.", data: existing.api_attributes)
  end
end
