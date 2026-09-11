# Offline subset of IEEE OUI registrations for common manufacturers. The public
# vendor service remains the full source; these answer without a network call
# and let the app work offline for the devices people most often look up.
# Idempotent: re-running updates names without touching user-created vendors.
SEED_VENDORS = {
  "00:03:93" => "Apple, Inc.",
  "00:1B:63" => "Apple, Inc.",
  "00:1E:C2" => "Apple, Inc.",
  "00:16:CB" => "Apple, Inc.",
  "00:00:0C" => "Cisco Systems, Inc",
  "00:1A:11" => "Google, Inc.",
  "3C:5A:B4" => "Google, Inc.",
  "00:15:5D" => "Microsoft Corporation",
  "00:50:F2" => "Microsoft Corporation",
  "00:1B:21" => "Intel Corporate",
  "00:14:22" => "Dell Inc.",
  "00:1F:29" => "Hewlett Packard",
  "00:15:99" => "Samsung Electronics Co.,Ltd",
  "00:E0:4C" => "Realtek Semiconductor Corp.",
  "B8:27:EB" => "Raspberry Pi Foundation",
  "DC:A6:32" => "Raspberry Pi Trading Ltd",
  "24:0A:C4" => "Espressif Inc.",
  "18:FE:34" => "Espressif Inc.",
  "50:C7:BF" => "TP-LINK TECHNOLOGIES CO.,LTD.",
  "00:14:6C" => "Netgear",
  "24:A4:3C" => "Ubiquiti Inc",
  "00:0E:58" => "Sonos, Inc.",
  "00:1E:10" => "Huawei Technologies Co.,Ltd",
  "28:6C:07" => "Xiaomi Communications Co Ltd",
  "00:04:4B" => "NVIDIA",
  "00:50:BA" => "D-Link Corporation",
  "00:1D:60" => "ASUSTek COMPUTER INC.",
  "00:50:56" => "VMware, Inc.",
  "00:0C:29" => "VMware, Inc.",
  "08:00:27" => "PCS Systemtechnik GmbH (VirtualBox)",
  "00:1C:42" => "Parallels, Inc."
}.freeze

SEED_VENDORS.each do |oui, name|
  vendor = Vendor.find_or_initialize_by(oui: oui)
  next if vendor.persisted? && vendor.source == "user"
  vendor.update!(name: name, source: "seed")
end
