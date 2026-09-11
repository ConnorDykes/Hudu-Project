require "test_helper"

class VendorLookupTest < ActiveSupport::TestCase
  test "provider text becomes vendor without surrounding whitespace" do
    stub_vendor(body: "  Example Devices, Inc.\n")
    result = VendorLookup.new.call(lookup_attributes[:mac])
    assert_equal "resolved", result.status
    assert_equal "Example Devices, Inc.", result.vendor
  end

  test "unknown does not parse provider error body" do
    stub_vendor(status: 404, body: "<html>Unknown</html>", content_type: "text/html")
    result = VendorLookup.new.call(lookup_attributes[:mac])
    assert_equal "unknown", result.status
    assert_nil result.vendor
  end

  test "bad successful responses are safe provider failures" do
    [ [ "", "text/plain" ], [ " " * 8, "text/plain" ], [ "a" * 256, "text/plain" ], [ "a" * 2048, "text/plain" ],
      [ "<html>SECRET</html>", "text/plain" ], [ "Example\nInjected", "text/plain" ], [ '{"vendor":"Example"}', "application/json" ], [ "\xFF".b, "text/plain" ] ].each do |body, type|
      stub_vendor(body: body, content_type: type)
      result = VendorLookup.new.call(lookup_attributes[:mac])
      assert_equal "failed", result.status, body.inspect
      assert_equal "vendor_unavailable", result.error_code
      assert_nil result.vendor
    end
  end

  test "transport errors and timeouts are mapped without leaking details or retrying" do
    [ [ Net::OpenTimeout, "vendor_timeout" ], [ Net::ReadTimeout, "vendor_timeout" ], [ Net::WriteTimeout, "vendor_timeout" ],
      [ SocketError, "vendor_unavailable" ], [ Errno::ECONNRESET, "vendor_unavailable" ],
      [ OpenSSL::SSL::SSLError, "vendor_unavailable" ], [ Net::HTTPBadResponse, "vendor_unavailable" ], [ EOFError, "vendor_unavailable" ] ].each do |exception, code|
      WebMock.reset!
      request = stub_request(:get, "https://api.macvendors.com/#{lookup_attributes[:mac]}").to_raise(exception.new("SECRET transport detail"))
      result = VendorLookup.new.call(lookup_attributes[:mac])
      assert_equal code, result.error_code
      assert_equal "failed", result.status
      assert_not_includes result.message, "SECRET"
      assert_requested request, times: 1
    end
  end

  test "redirects are not followed" do
    request = stub_request(:get, "https://api.macvendors.com/#{lookup_attributes[:mac]}")
      .to_return(status: 302, headers: { "Location" => "https://example.com/private" })
    assert_equal "vendor_unavailable", VendorLookup.new.call(lookup_attributes[:mac]).error_code
    assert_requested request, times: 1
    assert_not_requested :get, "https://example.com/private"
  end

  test "resolved and unknown outcomes are cached per MAC; failures are not" do
    Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
      resolved = stub_vendor
      2.times { assert_equal "Apple, Inc.", VendorLookup.new.call(lookup_attributes[:mac]).vendor }
      assert_requested resolved, times: 1

      unknown = stub_vendor(status: 404, mac: "02:00:00:00:00:01")
      2.times { assert_equal "unknown", VendorLookup.new.call("02:00:00:00:00:01").status }
      assert_requested unknown, times: 1

      failing = stub_vendor(status: 500, mac: "02:00:00:00:00:02")
      2.times { assert_equal "failed", VendorLookup.new.call("02:00:00:00:00:02").status }
      assert_requested failing, times: 2
    end
  end

  test "untrusted URL and non-normalized MAC cannot reach network" do
    [ "https://example.com/", "001b638445e6", "00:1B:63:84:45:E6/../secret" ].each do |mac|
      assert_raises(ArgumentError) { VendorLookup.new.call(mac) }
    end
    assert_not_requested :get, /./
  end
end
