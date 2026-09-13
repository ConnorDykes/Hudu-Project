class LookupsController < ApplicationController
  # GET /lookups            -> newest-first history
  # GET /lookups?mac=...    -> perform a lookup, as illustrated in the brief (200)
  def index
    return perform_lookup(:ok) if params.key?(:mac)
    render_page(Lookup.order(created_at: :desc, id: :desc))
  end

  # POST /lookups -> perform a lookup; the desktop client uses this form (201)
  def create
    perform_lookup(:created)
  end

  private

  def perform_lookup(success_status)
    lookup = Lookup.new(permitted_payload(:mac, :ip))
    lookup.validate!
    result = VendorLookup.new.call(lookup.mac)
    lookup.update!(vendor: result.vendor, status: result.status)

    if (error = result.error)
      render_error(error.http_status, error.code, error.message, data: lookup.api_attributes)
    else
      render json: { data: lookup.api_attributes }, status: success_status
    end
  end
end
