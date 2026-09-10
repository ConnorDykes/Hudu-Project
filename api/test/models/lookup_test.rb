require "test_helper"

class LookupTest < ActiveSupport::TestCase
  test "normalizes supported MAC formats" do
    [ "001b638445e6", "00-1b-63-84-45-e6", "00:1b:63:84:45:e6" ].each do |mac|
      lookup = Lookup.create!(mac: mac)
      assert_equal "00:1B:63:84:45:E6", lookup.reload.mac
    end
  end

  test "MAC syntax is validated without inferring address ownership" do
    %w[02:00:00:00:00:01 00:00:00:00:00:00 FF:FF:FF:FF:FF:FF 01:00:5E:00:00:01].each do |mac|
      assert Lookup.new(mac: mac).valid?
    end
  end

  test "vendor and status must be consistent" do
    assert_not Lookup.new(lookup_attributes.merge(status: "resolved")).valid?
    assert_not Lookup.new(lookup_attributes.merge(status: "failed", vendor: "Apple")).valid?
    assert_not Lookup.new(lookup_attributes.merge(status: "unrecognized")).valid?
  end

  test "IPv4 rejects subnet and non-address forms" do
    [ "127.1", "192.168.001.1", "localhost", "::1", "192.0.2.1/24" ].each do |ip|
      assert_not Lookup.new(lookup_attributes.merge(ip: ip)).valid?, ip
    end
  end
end
