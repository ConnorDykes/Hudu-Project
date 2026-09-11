ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "webmock/minitest"
require "minitest/mock"

WebMock.disable_net_connect!

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: 1)

    # A freshly prepared test database is seeded with the offline vendor OUIs.
    # Tests reason about provider behavior explicitly, so start each one with an
    # empty vendors table; the transactional wrapper restores the seeds after.
    setup { Vendor.delete_all }

    # Synthetic request data shared by model, service, and integration tests.
    def lookup_attributes
      { mac: "00:1B:63:84:45:E6", ip: "192.0.2.10" }
    end

    def event_attributes
      {
        event_id: "123e4567-e89b-42d3-a456-426614174000", process_name: "sleep",
        pid: 123, occurred_at: "2026-09-10T18:00:00.000Z"
      }
    end

    def stub_vendor(status: 200, body: "Apple, Inc.", mac: lookup_attributes[:mac], content_type: "text/plain; charset=utf-8")
      stub_request(:get, "https://api.macvendors.com/#{mac}")
        .to_return(status: status, body: body, headers: { "Content-Type" => content_type })
    end
  end
end
