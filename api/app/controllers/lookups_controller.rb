class LookupsController < ApplicationController
  def index
    render_page(Lookup.order(created_at: :desc, id: :desc))
  end

  def create
    lookup = Lookup.new(permitted_payload(:mac, :ip))
    lookup.validate!
    result = VendorLookup.new.call(lookup.mac)
    lookup.update!(vendor: result.vendor, status: result.status)

    if result.error_code
      render_error(result.http_status, result.error_code, result.message, data: lookup.api_attributes)
    else
      render json: { data: lookup.api_attributes }, status: :created
    end
  end
end
