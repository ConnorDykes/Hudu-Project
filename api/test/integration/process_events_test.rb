require "test_helper"

class ProcessEventsTest < ActionDispatch::IntegrationTest
  test "creates event with original occurrence time and server receipt timestamp" do
    travel_to Time.utc(2026, 9, 11, 18) do
      assert_difference("ProcessEvent.count", 1) do
        post "/process_events", params: event_attributes.merge(process_name: "Example Helper 日本語", id: 900, created_at: "2000-01-01"), as: :json
      end
      assert_response :created
      assert_equal({ "id" => ProcessEvent.last.id, "event_id" => event_attributes[:event_id], "process_name" => "Example Helper 日本語", "pid" => 123, "occurred_at" => "2026-09-10T18:00:00.000Z", "created_at" => "2026-09-11T18:00:00.000Z" }, response.parsed_body["data"])
    end
  end

  test "identical retry returns unchanged existing event" do
    post "/process_events", params: event_attributes, as: :json
    original = response.parsed_body
    travel 2.days do
      assert_no_difference("ProcessEvent.count") { post "/process_events", params: event_attributes, as: :json }
    end
    assert_response :ok
    assert_equal original, response.parsed_body
  end

  test "UUID case and equivalent timezone offset identify same event" do
    post "/process_events", params: event_attributes, as: :json
    assert_no_difference("ProcessEvent.count") do
      post "/process_events", params: event_attributes.merge(event_id: event_attributes[:event_id].upcase, occurred_at: "2026-09-10T12:00:00-06:00"), as: :json
    end
    assert_response :ok
    assert_equal event_attributes[:event_id], response.parsed_body.dig("data", "event_id")
  end

  test "each changed payload attribute conflicts without altering existing event" do
    original = ProcessEvent.create!(event_attributes)
    [ { pid: 124 }, { process_name: "other" }, { occurred_at: "2026-09-10T18:00:00.001Z" } ].each do |change|
      assert_no_difference("ProcessEvent.count") { post "/process_events", params: event_attributes.merge(change), as: :json }
      assert_response :conflict
      assert_equal "event_conflict", response.parsed_body.dig("error", "code")
      assert_equal original.attributes, original.reload.attributes
    end
  end

  test "microseconds survive storage and original-payload retries" do
    attributes = event_attributes.merge(occurred_at: "2026-09-10T18:00:00.123456Z")
    post "/process_events", params: attributes, as: :json
    assert_response :created
    assert_equal 123456, ProcessEvent.last.occurred_at.usec
    post "/process_events", params: attributes, as: :json
    assert_response :ok
  end

  test "database uniqueness race returns existing event" do
    existing = ProcessEvent.create!(event_attributes)
    # Simulate another request winning after our initial existence check.
    find_by = ProcessEvent.method(:find_by)
    calls = 0
    ProcessEvent.stub(:find_by, ->(*args) { calls += 1; calls == 1 ? nil : find_by.call(*args) }) do
      post "/process_events", params: event_attributes, as: :json
    end
    assert_response :ok
    assert_equal existing.id, response.parsed_body.dig("data", "id")
    assert_equal 1, ProcessEvent.count
  end

  test "database uniqueness race still rejects a conflicting payload" do
    ProcessEvent.create!(event_attributes)
    find_by = ProcessEvent.method(:find_by)
    calls = 0
    ProcessEvent.stub(:find_by, ->(*args) { calls += 1; calls == 1 ? nil : find_by.call(*args) }) do
      post "/process_events", params: event_attributes.merge(pid: 456), as: :json
    end
    assert_response :conflict
    assert_equal 1, ProcessEvent.count
  end

  test "invalid events are rejected without a row" do
    changes = [ { event_id: nil }, { event_id: "not-a-uuid" }, { event_id: [] }, { process_name: " " }, { process_name: 42 }, { process_name: "a" * 256 },
      { pid: 0 }, { pid: -1 }, { pid: "123" }, { pid: 1.5 }, { pid: true }, { pid: 2**63 },
      { occurred_at: nil }, { occurred_at: "2026-09-10" }, { occurred_at: "2026-09-10T18:00:00" }, { occurred_at: "2026-02-30T18:00:00Z" },
      { occurred_at: "2026-09-10T24:00:00Z" }, { occurred_at: "2026-09-10T18:00:00.1234567Z" }, { occurred_at: 123 }, { occurred_at: {} } ]
    changes.each do |change|
      assert_no_difference("ProcessEvent.count") { post "/process_events", params: event_attributes.merge(change), as: :json }
      assert_response :unprocessable_content, change.inspect
      assert_equal "invalid_input", response.parsed_body.dig("error", "code")
    end
    post "/process_events", params: { process_event: event_attributes }, as: :json
    assert_response :unprocessable_content
  end

  test "history orders by occurrence then id rather than delivery time" do
    first = ProcessEvent.create!(event_attributes)
    second = ProcessEvent.create!(event_attributes.merge(event_id: SecureRandom.uuid))
    older = ProcessEvent.create!(event_attributes.merge(event_id: SecureRandom.uuid, occurred_at: "2026-09-09T18:00:00Z"))
    get "/process_events", params: { limit: 2, offset: 1 }
    assert_response :ok
    assert_equal [ first.id, older.id ], response.parsed_body["data"].map { |row| row["id"] }
    assert_equal({ "limit" => 2, "offset" => 1, "total" => 3 }, response.parsed_body["meta"])
    get "/process_events"
    assert_equal second.id, response.parsed_body["data"].first["id"]
  end
end
