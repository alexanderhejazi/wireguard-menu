cask "archway" do
  version "0.2.0"
  sha256 "0720e0e376418c103b79347a18277d5644247e28aefa369a7a5b21deaf61d08a"

  url "https://github.com/mnilsson/archway/releases/download/v#{version}/Archway-#{version}-universal.dmg"
  name "Archway"
  desc "Menu bar app for wg-quick tunnels"
  homepage "https://github.com/mnilsson/archway"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on formula: ["wireguard-tools", "wireguard-go"]
  depends_on macos: :ventura

  app "Archway.app"

  zap trash: [
    "~/Library/Application Support/Archway",
    "~/Library/Preferences/se.mnilsson.archway.plist",
  ]
end
