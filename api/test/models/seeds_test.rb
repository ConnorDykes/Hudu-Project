require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "optional seeds are synthetic idempotent and make no external requests" do
    original = ENV["DEMO_SEEDS"]
    ENV["DEMO_SEEDS"] = "1"
    assert_difference([ "Lookup.count", "ProcessEvent.count" ], 1) { load Rails.root.join("db/seeds.rb") }
    assert_no_difference([ "Lookup.count", "ProcessEvent.count" ]) { load Rails.root.join("db/seeds.rb") }
    assert_equal "unknown", Lookup.last.status
    assert_includes ProcessEvent.last.process_name, "Synthetic fixture"
    assert_not_requested :get, /./
  ensure
    ENV["DEMO_SEEDS"] = original
  end

  test "default database preparation does not invent history" do
    original = ENV.delete("DEMO_SEEDS")
    assert_no_difference([ "Lookup.count", "ProcessEvent.count" ]) { load Rails.root.join("db/seeds.rb") }
  ensure
    ENV["DEMO_SEEDS"] = original
  end
end
