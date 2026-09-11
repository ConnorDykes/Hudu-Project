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

  test "unexpected failures propagate in the default test environment" do
    Lookup.stub(:order, ->(*) { raise "unexpected bug" }) do
      error = assert_raises(RuntimeError) { get "/lookups" }
      assert_equal "unexpected bug", error.message
    end
  end

  test "production exception handling returns JSON without internal details" do
    with_public_exception_responses do
      Lookup.stub(:order, ->(*) { raise "SECRET internal detail" }) do
        get "/lookups"
      end
    end
    assert_response :internal_server_error
    assert_equal "application/json", response.media_type
    assert_equal "internal_error", response.parsed_body.dig("error", "code")
    assert_not_includes response.body, "SECRET"
  end

  test "framework client errors keep their status in the production envelope" do
    [ [ ActionController::BadRequest, 400 ], [ ActionController::UnknownFormat, 406 ],
      [ ActionController::MethodNotAllowed, 405 ] ].each do |exception, status|
      with_public_exception_responses do
        Lookup.stub(:order, ->(*) { raise exception, "SECRET request detail" }) do
          get "/lookups"
        end
      end
      assert_response status
      assert_equal "application/json", response.media_type
      assert_not_includes response.body, "SECRET"
    end
  end

  test "production HEAD failures return error headers without a body" do
    with_public_exception_responses do
      Lookup.stub(:order, ->(*) { raise "SECRET internal detail" }) do
        head "/lookups"
      end
    end
    assert_response :internal_server_error
    assert_equal "application/json", response.media_type
    assert_empty response.body
    assert_operator response.headers["content-length"].to_i, :>, 0
  end

  test "malformed query structure returns 400 instead of being treated as a server bug" do
    with_public_exception_responses { get "/lookups?limit=1&limit[nested]=2" }
    assert_response :bad_request
    assert_equal "invalid_input", response.parsed_body.dig("error", "code")
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
    [ "/lookups", "/process_events", "/vendors" ].each do |path|
      assert_no_difference([ "Lookup.count", "ProcessEvent.count", "Vendor.count" ]) do
        post path, params: '{"broken":', headers: { "CONTENT_TYPE" => "application/json" }
      end
      assert_response :bad_request
      assert_equal "application/json", response.media_type
      assert_equal "invalid_json", response.parsed_body.dig("error", "code")
    end
  end

  test "all collection endpoints reject invalid pagination" do
    [ "/lookups", "/process_events", "/vendors" ].each do |path|
      [ { limit: "0" }, { limit: "101" }, { limit: "-1" }, { limit: "1.5" }, { limit: "1abc" }, { limit: "" }, { limit: [ "1" ] },
        { offset: "-1" }, { offset: "1.1" }, { offset: "abc" }, { offset: "" }, { offset: { nested: "1" } }, { offset: (2**63).to_s } ].each do |params|
        get path, params: params
        assert_response :unprocessable_content, params.inspect
        assert_equal "invalid_input", response.parsed_body.dig("error", "code")
      end
    end
  end

  test "all collection endpoints accept maximum page size and return empty pages beyond end" do
    [ "/lookups", "/process_events", "/vendors" ].each do |path|
      get path, params: { limit: 100, offset: 1000 }
      assert_response :ok
      assert_equal({ "data" => [], "meta" => { "limit" => 100, "offset" => 1000, "total" => 0 } }, response.parsed_body)
    end
  end

  private

  def with_public_exception_responses(&block)
    public_config = Rails.application.env_config.merge(
      "action_dispatch.show_exceptions" => :all,
      "action_dispatch.show_detailed_exceptions" => false
    )
    Rails.application.stub(:env_config, public_config, &block)
  end
end
