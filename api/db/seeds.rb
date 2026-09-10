# Optional synthetic display fixtures. These are not observations of this machine,
# provider responses, or records of a real termination. Default db:prepare is empty.
if ENV["DEMO_SEEDS"] == "1"
  fixture_time = Time.utc(2026, 9, 10, 18)
  Lookup.find_or_create_by!(mac: "02:00:00:00:00:01", ip: "192.0.2.10") do |lookup|
    lookup.status = "unknown"
    lookup.created_at = fixture_time
  end
  ProcessEvent.find_or_create_by!(event_id: "00000000-0000-4000-8000-000000000001") do |event|
    event.process_name = "Synthetic fixture - no process was terminated"
    event.pid = 12345
    event.occurred_at = fixture_time
    event.created_at = fixture_time
  end
end
