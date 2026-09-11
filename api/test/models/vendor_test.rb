require "test_helper"

class VendorTest < ActiveSupport::TestCase
  test "normalizes only consistently separated OUI and MAC strings" do
    %w[0211aa 02:11:aa 02-11-aa 0211aa334455 02:11:aa:33:44:55 02-11-aa-33-44-55].each do |value|
      vendor = Vendor.new(oui: value, name: "Example")
      assert vendor.valid?, value
      assert_equal "02:11:AA", vendor.oui
    end
  end

  test "rejects malformed separators and non-string vendor prefixes" do
    [ "0:21:12:2", "02::11:22", "02:11-22", "02-11:22:33:44:55", ":021122", "021122-",
      "02:11:22\n", "02.11.22", 21122, nil ].each do |value|
      assert_nil Vendor.oui_for(value), value.inspect
      assert_not Vendor.new(oui: value, name: "Example").valid?, value.inspect
    end
  end

  test "database enforces unique vendor prefixes without validation" do
    vendor = Vendor.create!(oui: "02:11:22", name: "Original")
    assert_raises(ActiveRecord::RecordNotUnique) { Vendor.insert_all!([ vendor.attributes.except("id") ]) }
    assert_equal 1, Vendor.count
  end
end
