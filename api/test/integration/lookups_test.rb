require "test_helper"

class LookupsTest < ActionDispatch::IntegrationTest
  test "raw JSON request parses through Rails without parser stubs" do
    stub_vendor
    post "/lookups", params: '{"mac":"001B638445E6"}', headers: { "CONTENT_TYPE" => "application/json" }
    assert_response :created
    assert_equal "00:1B:63:84:45:E6", response.parsed_body.dig("data", "mac")
    assert_equal "Apple, Inc.", Lookup.last.vendor
  end

  test "creates a normalized persisted result with only contract fields" do
    provider = stub_vendor
    travel_to Time.utc(2026, 9, 10, 18) do
      assert_difference("Lookup.count", 1) do
        post "/lookups", params: lookup_attributes.merge(mac: "001b638445e6", vendor: "Injected", status: "failed", id: 900, created_at: "2000-01-01"), as: :json
      end
      assert_response :created
      record = Lookup.last
      assert_equal({ "id" => record.id, "ip" => "192.0.2.10", "mac" => "00:1B:63:84:45:E6", "vendor" => "Apple, Inc.", "status" => "resolved", "created_at" => "2026-09-10T18:00:00.000Z" }, response.parsed_body["data"])
      assert_equal "Apple, Inc.", record.vendor
      assert_requested provider, times: 1
    end
  end

  test "hyphenated MAC without IP returns unknown and persists it" do
    stub_vendor(status: 404)
    assert_difference("Lookup.count", 1) do
      post "/lookups", params: { mac: "00-1b-63-84-45-e6" }, as: :json
    end
    assert_response :created
    assert_nil response.parsed_body.dig("data", "ip")
    assert_nil response.parsed_body.dig("data", "vendor")
    assert_equal "unknown", Lookup.last.status
  end

  test "locally administered MAC is accepted" do
    stub_vendor(status: 404, mac: "02:00:00:00:00:01")
    post "/lookups", params: { mac: "02:00:00:00:00:01" }, as: :json
    assert_response :created
    assert_equal "unknown", Lookup.last.status
  end

  test "invalid inputs do not persist or call provider" do
    invalid = [ {}, { mac: 112233445566 }, { mac: "00:1b-63:84:45:e6" }, { mac: "001b.6384.45e6" }, { mac: "00:1B:63:84:45:E6\n" },
      { mac: [ lookup_attributes[:mac] ] }, { ip: "::1" }, { ip: "999.1.1.1" }, { ip: "192.0.2.1/24" }, { ip: "" }, { ip: { address: "192.0.2.10" } }, { ip: 123 }, { lookup: lookup_attributes } ]
    invalid.each do |attributes|
      payload = attributes.key?(:ip) ? lookup_attributes.merge(attributes) : attributes
      assert_no_difference("Lookup.count") { post "/lookups", params: payload, as: :json }
      assert_response :unprocessable_content, payload.inspect
      assert_equal "invalid_input", response.parsed_body.dig("error", "code")
    end
    assert_not_requested :get, /api\.macvendors\.com/
  end

  test "provider failures persist and return safe typed errors plus history record" do
    [ [ 500, 502, "vendor_unavailable" ], [ 429, 503, "vendor_rate_limited" ], [ 302, 502, "vendor_unavailable" ] ].each do |upstream, status, code|
      stub_vendor(status: upstream, body: "SECRET UPSTREAM BODY")
      assert_difference("Lookup.count", 1) { post "/lookups", params: lookup_attributes, as: :json }
      assert_response status
      assert_equal code, response.parsed_body.dig("error", "code")
      assert_equal "failed", response.parsed_body.dig("data", "status")
      assert_equal Lookup.last.id, response.parsed_body.dig("data", "id")
      assert_nil Lookup.last.vendor
      assert_not_includes response.body, "SECRET"
    end
    get "/lookups"
    assert_equal 3, response.parsed_body.dig("meta", "total")
    assert response.parsed_body["data"].all? { |row| row["status"] == "failed" }
  end

  test "timeout persists and returns 504" do
    stub_request(:get, "https://api.macvendors.com/#{lookup_attributes[:mac]}").to_timeout
    assert_difference("Lookup.count", 1) { post "/lookups", params: lookup_attributes, as: :json }
    assert_response :gateway_timeout
    assert_equal "vendor_timeout", response.parsed_body.dig("error", "code")
    assert_equal "failed", Lookup.last.status
  end

  test "malformed success body is a persisted provider failure" do
    stub_vendor(body: "<html>SECRET</html>", content_type: "text/html")
    post "/lookups", params: lookup_attributes, as: :json
    assert_response :bad_gateway
    assert_equal "failed", Lookup.last.status
    assert_not_includes response.body, "SECRET"
  end

  test "history orders by creation time then id with pagination and total" do
    old = Lookup.create!(lookup_attributes.merge(created_at: 2.days.ago))
    time = Time.current
    first = Lookup.create!(lookup_attributes.merge(created_at: time))
    last = Lookup.create!(lookup_attributes.merge(created_at: time))
    get "/lookups", params: { limit: 2, offset: 1 }
    assert_response :ok
    assert_equal [ first.id, old.id ], response.parsed_body["data"].map { |row| row["id"] }
    assert_equal({ "limit" => 2, "offset" => 1, "total" => 3 }, response.parsed_body["meta"])
    get "/lookups"
    assert_equal [ last.id, first.id, old.id ], response.parsed_body["data"].map { |row| row["id"] }
    assert_equal 30, response.parsed_body.dig("meta", "limit")
  end
end
