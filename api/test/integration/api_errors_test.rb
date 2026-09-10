require "test_helper"

class ApiErrorsTest < ActionDispatch::IntegrationTest
  test "health queries database" do
    connection = ActiveRecord::Base.connection
    queried = false
    connection.stub(:select_value, ->(sql) { queried = sql == "SELECT 1"; 1 }) do
      get "/health"
    end
    assert queried
    assert_response :ok
    assert_equal({ "status" => "ok" }, response.parsed_body)
  end

  test "health returns safe unavailable error when database fails" do
    ActiveRecord::Base.connection.stub(:select_value, ->(*) { raise ActiveRecord::ConnectionNotEstablished, "SECRET DB PATH" }) do
      get "/health"
    end
    assert_response :service_unavailable
    assert_equal "database_unavailable", response.parsed_body.dig("error", "code")
    assert_not_includes response.body, "SECRET"
  end

  test "unknown routes and unsupported methods return JSON 404" do
    [ "/", "/missing", "/lookups/1", "/up", "/missing.html" ].each do |path|
      get path
      assert_response :not_found
      assert_equal "application/json", response.media_type
      assert_equal "not_found", response.parsed_body.dig("error", "code")
    end
    delete "/lookups"
    assert_response :not_found
  end

  test "malformed JSON returns JSON 400 without persisting" do
    [ "/lookups", "/process_events" ].each do |path|
      assert_no_difference([ "Lookup.count", "ProcessEvent.count" ]) do
        post path, params: '{"broken":', headers: { "CONTENT_TYPE" => "application/json" }
      end
      assert_response :bad_request
      assert_equal "application/json", response.media_type
      assert_equal "invalid_json", response.parsed_body.dig("error", "code")
    end
  end

  test "both histories reject invalid pagination" do
    [ "/lookups", "/process_events" ].each do |path|
      [ { limit: "0" }, { limit: "101" }, { limit: "-1" }, { limit: "1.5" }, { limit: "1abc" }, { limit: "" }, { limit: [ "1" ] },
        { offset: "-1" }, { offset: "1.1" }, { offset: "abc" }, { offset: "" }, { offset: { nested: "1" } }, { offset: (2**63).to_s } ].each do |params|
        get path, params: params
        assert_response :unprocessable_content, params.inspect
        assert_equal "invalid_input", response.parsed_body.dig("error", "code")
      end
    end
  end

  test "both histories accept maximum page size and return empty pages beyond end" do
    [ "/lookups", "/process_events" ].each do |path|
      get path, params: { limit: 100, offset: 1000 }
      assert_response :ok
      assert_equal({ "data" => [], "meta" => { "limit" => 100, "offset" => 1000, "total" => 0 } }, response.parsed_body)
    end
  end
end
