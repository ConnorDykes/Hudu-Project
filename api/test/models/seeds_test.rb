require "test_helper"

class SeedsTest < ActiveSupport::TestCase
  test "seed vendors load idempotently and never overwrite a user-named vendor" do
    Vendor.create!(oui: "00:1B:63", name: "My renamed Apple device", source: "user")
    load Rails.root.join("db/seeds.rb")
    seeded = Vendor.count
    assert_operator seeded, :>=, 25
    assert_silent do
      assert_no_difference("Vendor.count") { load Rails.root.join("db/seeds.rb") }
    end
    assert_equal "My renamed Apple device", Vendor.find_by!(oui: "00:1B:63").name
    assert_equal "Cisco Systems, Inc", Vendor.find_by!(oui: "00:00:0C").name
    assert Vendor.where(source: "seed").all? { |vendor| vendor.oui.match?(Vendor::OUI_FORMAT) }
    assert_not_requested :get, /./
  end
end
