class Sxr < Formula
  include Language::Python::Virtualenv

  desc "Session x-ray: read Claude Code and Codex sessions from the terminal"
  homepage "https://github.com/ivorpad/sxr"
  url "https://github.com/ivorpad/sxr/archive/refs/tags/v0.1.0.tar.gz"
  sha256 "55f34da9e16d015a5d2968174f61ee671b73592da8559faa6d17e9e00c159b95"
  license "MIT"

  depends_on "python@3.13"

  def install
    venv = virtualenv_create(libexec, "python3.13")
    system libexec/"bin/pip", "install", buildpath.to_s
    bin.install_symlink libexec/"bin/sxr"
  end

  test do
    assert_match "session x-ray", shell_output("#{bin}/sxr --help")
  end
end
