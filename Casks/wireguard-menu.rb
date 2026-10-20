cask "wireguard-menu" do
  version "0.1.0"
  sha256 "9a7f276dcd42949ec6f7919554b23724a8528bc429cac158617daee88cc1f499"

  url "https://github.com/mnilsson/wireguard-menu/releases/download/v#{version}/WireGuard-Menu-#{version}-universal.dmg"
  name "WireGuard Menu"
  desc "Menu bar app for wg-quick tunnels"
  homepage "https://github.com/mnilsson/wireguard-menu"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on formula: ["wireguard-tools", "wireguard-go"]
  depends_on macos: :ventura

  app "WireGuard Menu.app"

  zap trash: [
    "~/Library/Application Support/WireGuard Menu",
    "~/Library/Preferences/se.mnilsson.wireguard-menu.plist",
  ]
end
