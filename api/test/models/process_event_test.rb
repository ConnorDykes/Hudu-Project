require "test_helper"

class ProcessEventTest < ActiveSupport::TestCase
  test "unique database index prevents duplicate event IDs even without model validation" do
    event = ProcessEvent.create!(event_attributes)
    duplicate = event.attributes.except("id")
    assert_raises(ActiveRecord::RecordNotUnique) { ProcessEvent.insert_all!([ duplicate ]) }
    assert_equal 1, ProcessEvent.count
    index = ProcessEvent.connection.indexes(:process_events).find { |item| item.columns == [ "event_id" ] }
    assert index.unique
  end

  test "database rejects nonpositive PIDs without model validation" do
    event = ProcessEvent.create!(event_attributes)
    assert_raises(ActiveRecord::StatementInvalid) { event.update_column(:pid, 0) }
    assert_equal 123, event.reload.pid
  end

  test "occurrence normalizes to UTC and preserves microseconds" do
    event = ProcessEvent.create!(event_attributes.merge(occurred_at: "2026-09-10T12:00:00.123456-06:00"))
    assert_equal "2026-09-10T18:00:00.123456Z", event.reload.occurred_at.iso8601(6)
  end
end
