require "net/http"
require "timeout"

class VendorLookup
  ENDPOINT = "https://api.macvendors.com/"
  OPEN_TIMEOUT = 2
  READ_TIMEOUT = 3
  TOTAL_TIMEOUT = 6
  MAX_BODY_BYTES = 1024
  class DeadlineExceeded < StandardError; end
  class InvalidResponse < StandardError; end
  Result = Data.define(:status, :vendor, :http_status, :error_code, :message)

  def call(mac)
    # Only normalized MACs can reach the fixed provider host; never accept a URL.
    raise ArgumentError, "Expected a normalized MAC" unless mac.match?(/\A(?:[0-9A-F]{2}:){5}[0-9A-F]{2}\z/)
    uri = URI("#{ENDPOINT}#{mac}")
    response_code, content_type, body = fetch(uri)
    case response_code
    when "200"
      body.force_encoding(Encoding::UTF_8)
      raise InvalidResponse unless body.valid_encoding?
      vendor = body.strip
      unless content_type == "text/plain" && vendor.present? && vendor.length <= 255 && !vendor.match?(/[[:cntrl:]<>]/)
        raise InvalidResponse
      end
      Result.new(status: "resolved", vendor: vendor, http_status: 201, error_code: nil, message: nil)
    when "404"
      Result.new(status: "unknown", vendor: nil, http_status: 201, error_code: nil, message: nil)
    when "429"
      failure(503, "vendor_rate_limited", "Vendor provider rate limit reached. Please try again later.")
    else
      failure(502, "vendor_unavailable", "Vendor provider is unavailable. Please try again later.")
    end
  rescue Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, DeadlineExceeded
    failure(504, "vendor_timeout", "Vendor provider timed out. Please try again later.")
  rescue InvalidResponse, SocketError, IOError, SystemCallError, OpenSSL::SSL::SSLError, Net::HTTPBadResponse, Net::ProtocolError
    failure(502, "vendor_unavailable", "Vendor provider is unavailable. Please try again later.")
  end

  private

  def fetch(uri)
    Timeout.timeout(TOTAL_TIMEOUT, DeadlineExceeded) do
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = OPEN_TIMEOUT
      http.read_timeout = READ_TIMEOUT
      http.write_timeout = READ_TIMEOUT
      http.max_retries = 0
      request = Net::HTTP::Get.new(uri)
      request["Accept"] = "text/plain"
      request["User-Agent"] = "Hudu-Project/1.0"
      http.request(request) do |response|
        body = +""
        # Error bodies are deliberately neither parsed nor returned to clients.
        if response.code == "200"
          response.read_body do |chunk|
            raise InvalidResponse if body.bytesize + chunk.bytesize > MAX_BODY_BYTES
            body << chunk
          end
        end
        return [ response.code, response.content_type, body ]
      end
    end
  end

  def failure(http_status, code, message)
    Result.new(status: "failed", vendor: nil, http_status: http_status, error_code: code, message: message)
  end
end
