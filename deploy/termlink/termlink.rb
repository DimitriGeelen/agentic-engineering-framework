# Homebrew formula for TermLink
#
# To use: Create a tap repo (github.com/DimitriGeelen/homebrew-termlink)
# and place this file as Formula/termlink.rb
#
# Users install with: brew install DimitriGeelen/termlink/termlink
# Or: brew tap DimitriGeelen/termlink && brew install termlink

class Termlink < Formula
  desc "Cross-terminal session communication tool for agentic workflows"
  homepage "https://github.com/DimitriGeelen/termlink"
  version "1.0.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/DimitriGeelen/termlink/releases/download/v#{version}/termlink-darwin-aarch64"
      sha256 "REPLACE_WITH_AARCH64_SHA256"

      def install
        bin.install "termlink-darwin-aarch64" => "termlink"
      end
    end

    on_intel do
      url "https://github.com/DimitriGeelen/termlink/releases/download/v#{version}/termlink-darwin-x86_64"
      sha256 "REPLACE_WITH_X86_64_SHA256"

      def install
        bin.install "termlink-darwin-x86_64" => "termlink"
      end
    end
  end

  on_linux do
    url "https://github.com/DimitriGeelen/termlink/releases/download/v#{version}/termlink-linux-x86_64"
    sha256 "REPLACE_WITH_LINUX_SHA256"

    def install
      bin.install "termlink-linux-x86_64" => "termlink"
    end
  end

  test do
    assert_match "termlink", shell_output("#{bin}/termlink --version")
  end
end
