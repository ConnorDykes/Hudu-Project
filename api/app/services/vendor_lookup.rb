require "net/http"

# Resolves a normalized MAC through the public MACVendors service.
#
# Resolved and unknown outcomes are cached so repeated lookups of the same
# device do not consume the provider's rate limit; provider failures are never
# cached. Request time is bounded by Net::HTTP's own phase timeouts rather than
# Timeout.timeout, which is unsafe inside a threaded Puma worker.
class VendorLookup
  ENDPOINT = "https://api.macvendors.com/"
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3
  MAX_BODY_BYTES = 1024
  CACHE_TTL = 24.hours
  class InvalidResponse < StandardError; end
  Result = Data.define(:status, :vendor, :http_status, :error_code, :message)

  def call(mac)
    # Only normalized MACs can reach the fixed provider host; never accept a URL.
    raise ArgumentError, "Expected a normalized MAC" unless mac.match?(Lookup::NORMALIZED_FORMAT)
    cached = Rails.cache.read(cache_key(mac))
    return Result.new(**cached) if cached

    result = fetch(mac)
    Rails.cache.write(cache_key(mac), result.to_h, expires_in: CACHE_TTL) unless result.error_code
    result
  end

  private

  def cache_key(mac) = "vendor_lookup/v1/#{mac}"

  def fetch(mac)
    response_code, content_type, body = request(URI("#{ENDPOINT}#{mac}"))
    case response_code
    when "200" then resolved(body, content_type)
    when "404" then Result.new(status: "unknown", vendor: nil, http_status: 201, error_code: nil, message: nil)
    when "429" then failure(503, "vendor_rate_limited", "Vendor provider rate limit reached. Please try again later.", "HTTP 429")
    else failure(502, "vendor_unavailable", "Vendor provider is unavailable. Please try again later.", "HTTP #{response_code}")
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout => error
    failure(504, "vendor_timeout", "Vendor provider timed out. Please try again later.", error.class.name)
  rescue InvalidResponse, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError => error
    failure(502, "vendor_unavailable", "Vendor provider is unavailable. Please try again later.", error.class.name)
  end

  def resolved(body, content_type)
    body.force_encoding(Encoding::UTF_8)
    raise InvalidResponse unless body.valid_encoding?
    vendor = body.strip
    unless content_type == "text/plain" && vendor.present? && vendor.length <= 255 && !vendor.match?(/[[:cntrl:]<>]/)
      raise InvalidResponse
    end
    Result.new(status: "resolved", vendor: vendor, http_status: 201, error_code: nil, message: nil)
  end

  def request(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.open_timeout = OPEN_TIMEOUT
    http.read_timeout = READ_TIMEOUT
    http.write_timeout = READ_TIMEOUT
    http.max_retries = 0
    get = Net::HTTP::Get.new(uri)
    get["Accept"] = "text/plain"
    get["User-Agent"] = "Hudu-Project/1.0"
    outcome = nil
    http.start do |connection|
      connection.request(get) do |response|
        body = +""
        # Error bodies are deliberately neither parsed nor returned to clients.
        if response.code == "200"
          response.read_body do |chunk|
            raise InvalidResponse if body.bytesize + chunk.bytesize > MAX_BODY_BYTES
            body << chunk
          end
        end
        outcome = [ response.code, response.content_type, body ]
      end
    end
    outcome
  end

  def failure(http_status, code, message, cause)
    # The cause is an exception class or HTTP status only; provider bodies never reach logs or clients.
    Rails.logger.warn { "VendorLookup #{code} (#{cause})" }
    Result.new(status: "failed", vendor: nil, http_status: http_status, error_code: code, message: message)
  end
end
