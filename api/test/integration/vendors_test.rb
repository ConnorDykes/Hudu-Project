require "test_helper"

class VendorsTest < ActionDispatch::IntegrationTest
  test "creates a user vendor from a full MAC and stores only its OUI" do
    assert_difference("Vendor.count", 1) do
      post "/vendors", params: { mac: "02-11-22-33-44-55", name: "Lab sensor" }, as: :json
    end
    assert_response :created
    assert_equal({ "oui" => "02:11:22", "name" => "Lab sensor", "source" => "user" },
      response.parsed_body["data"].slice("oui", "name", "source"))
  end

  test "accepts a bare OUI and rejects a second vendor for the same OUI" do
    post "/vendors", params: { oui: "021122", name: "First" }, as: :json
    assert_response :created
    assert_no_difference("Vendor.count") do
      post "/vendors", params: { mac: "02:11:22:AA:BB:CC", name: "Second" }, as: :json
    end
    assert_response :conflict
    assert_equal "vendor_exists", response.parsed_body.dig("error", "code")
    assert_equal "First", response.parsed_body.dig("data", "name")
  end

  test "invalid vendors are rejected without a row" do
    [ { mac: "02:11:22:33:44:55" }, { name: "No address" }, { mac: "zz:11:22", name: "Bad" },
      { mac: "02:11:22:33:44:55", name: " " }, { mac: "02:11:22:33:44:55", name: "a" * 256 },
      { mac: "02:11:22:33:44:55", name: "<script>" }, { mac: [ "02:11:22" ], name: "Array" },
      { mac: "02:11:22:33:44:55", name: 42 }, { oui: "0:21:12:2", name: "Malformed" },
      { mac: "02:11-22:33:44:55", name: "Mixed separators" } ].each do |payload|
      assert_no_difference("Vendor.count") { post "/vendors", params: payload, as: :json }
      assert_response :unprocessable_content, payload.inspect
      assert_equal "invalid_input", response.parsed_body.dig("error", "code")
    end
  end

  test "a concurrent vendor insertion returns 409 and preserves the existing vendor" do
    existing = Vendor.create!(oui: "02:11:22", name: "First")
    find_by = Vendor.method(:find_by)
    calls = 0
    Vendor.stub(:find_by, ->(*args) { calls += 1; calls == 1 ? nil : find_by.call(*args) }) do
      assert_no_difference("Vendor.count") do
        post "/vendors", params: { oui: "02:11:22", name: "Second" }, as: :json
      end
    end
    assert_response :conflict
    assert_equal "vendor_exists", response.parsed_body.dig("error", "code")
    assert_equal existing.id, response.parsed_body.dig("data", "id")
    assert_equal "First", existing.reload.name
  end

  test "a named vendor resolves lookups locally without calling the provider" do
    post "/vendors", params: { mac: "02:11:22:33:44:55", name: "Lab sensor" }, as: :json
    assert_difference("Lookup.count", 1) do
      post "/lookups", params: { mac: "02:11:22:AA:BB:CC" }, as: :json
    end
    assert_response :created
    assert_equal "Lab sensor", response.parsed_body.dig("data", "vendor")
    assert_equal "resolved", response.parsed_body.dig("data", "status")
    assert_not_requested :get, /api\.macvendors\.com/
  end

  test "vendor list is paginated and sorted by name" do
    Vendor.create!(oui: "02:00:00", name: "Zeta", source: "user")
    Vendor.create!(oui: "02:00:01", name: "Alpha", source: "seed")
    get "/vendors", params: { limit: 1 }
    assert_response :ok
    assert_equal [ "Alpha" ], response.parsed_body["data"].map { |row| row["name"] }
    assert_equal 2, response.parsed_body.dig("meta", "total")
  end
end
