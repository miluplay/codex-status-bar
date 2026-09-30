class CodexStatusBar < Formula
  desc "Menu bar app that shows local Codex activity"
  homepage "https://github.com/yuriipalam/codex-status-bar"
  url "https://github.com/yuriipalam/codex-status-bar/archive/refs/tags/v0.3.0.tar.gz"
  sha256 "18caa8650dd52da3c44b372d8dd2293c51b143610d050835c317fe60665ab517"
  license "MIT"
  head "https://github.com/yuriipalam/codex-status-bar.git", branch: "main"

  depends_on macos: :ventura

  def install
    ENV["SWIFT_BUILD_FLAGS"] = "--disable-sandbox"
    # Support both this fork's layout and the pinned upstream source archive.
    if File.exist?("Engineering/Build/build.sh")
      system "./Engineering/Build/build.sh", "--release"
      prefix.install "Engineering/Build/build/CodexStatusBar.app"
    else
      system "./build.sh", "--release"
      prefix.install "build/CodexStatusBar.app"
    end

    (bin/"codex-status-bar").write <<~EOS
      #!/bin/bash
      exec open "#{opt_prefix}/CodexStatusBar.app"
    EOS
    chmod 0755, bin/"codex-status-bar"
  end

  test do
    assert_path_exists prefix/"CodexStatusBar.app/Contents/MacOS/CodexStatusBar"
    system "codesign", "--verify", "--deep", "--strict", "--verbose=2", prefix/"CodexStatusBar.app"
  end
end
