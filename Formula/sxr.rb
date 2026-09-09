class Sxr < Formula
  desc "Session x-ray: read Claude Code and Codex sessions from the terminal"
  homepage "https://github.com/ivorpad/sxr"
  version "0.12.0"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/ivorpad/sxr/releases/download/v0.12.0/sxr-0.12.0-macos-arm64.tar.gz"
      sha256 "bc21f7120de3290ed5dd45d5f3f84dbdd3e8896906eb28e957cb81f4575e8ca6"
    end
    on_intel do
      url "https://github.com/ivorpad/sxr/releases/download/v0.12.0/sxr-0.12.0-macos-x86_64.tar.gz"
      sha256 "bfbed73bb360075394c329718e9f7f2cef27d424f9d3826f234ee32a89d2f877"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/ivorpad/sxr/releases/download/v0.12.0/sxr-0.12.0-linux-arm64.tar.gz"
      sha256 "cbf5ae4d6ab4b61fb46e784af79e6a74f52fef475cdc4571df770f4c11b873d4"
    end
    on_intel do
      url "https://github.com/ivorpad/sxr/releases/download/v0.12.0/sxr-0.12.0-linux-x86_64.tar.gz"
      sha256 "f0fca573e5604d81670a8c42b869c51c1cb02a0bf3c9ad2313f57bb896c4d8ba"
    end
  end

  def install
    libexec.install Dir["*"]
    bin.install_symlink libexec/"sxr"
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/sxr --version")
    assert_match "--archives", shell_output("#{bin}/sxr --help")

    ENV["CLAUDE_CONFIG_DIR"] = (testpath/"claude").to_s
    ENV["SXR_CACHE_DIR"] = (testpath/"cache").to_s
    session = testpath/"claude/projects/example/session.jsonl"
    session.dirname.mkpath
    record = { type: "user", timestamp: "2026-01-01T00:00:00Z", cwd: testpath.to_s,
               message: { role: "user", content: "brew-index-first" } }
    session.write "#{JSON.generate(record)}\n"

    system bin/"sxr", "--path", testpath, "index"
    assert_path_exists testpath/"cache/search.sqlite3"
    assert_match "brew-index-first", shell_output("#{bin}/sxr --path #{testpath} grep -F brew-index-first")

    record[:message][:content] = "brew-index-appended"
    session.open("a") { |file| file.puts JSON.generate(record) }
    assert_match "brew-index-appended", shell_output("#{bin}/sxr --path #{testpath} grep -F brew-index-appended")

    command = "#{bin}/sxr show --file #{session} --around 1 --context 0"
    first = shell_output(command)
    assert_match "brew-index-first", first
    assert_equal first, shell_output(command)

    rollout = testpath/"rollout.jsonl"
    metadata = { type: "session_meta", payload: { id: "brew-codex", cwd: testpath.to_s } }
    call = { type:    "response_item",
             payload: { type: "function_call", name: "exec_command", call_id: "test-call",
                        arguments: JSON.generate({ cmd: "false" }) } }
    rollout.write "#{JSON.generate(metadata)}\n#{JSON.generate(call)}\n"
    command = "#{bin}/sxr show --file #{rollout} --around 2 --context 0"
    first = shell_output(command)
    assert_match "exec_command", first
    assert_equal first, shell_output(command)

    result = { type:    "response_item",
               payload: { type: "function_call_output", call_id: "test-call",
                          output: JSON.generate({ output: "failed", metadata: { exit_code: 1 } }) } }
    rollout.open("a") { |file| file.puts JSON.generate(result) }
    first = shell_output(command)
    assert_match "-> err", first
    assert_equal first, shell_output(command)

    ENV["CODEX_HOME"] = (testpath/"codex").to_s
    indexed_rollout = testpath/"codex/sessions/rollout-brew.jsonl"
    indexed_rollout.dirname.mkpath
    indexed_rollout.write rollout.read
    query = "#{bin}/sxr find 'brew-index-first false' --all-projects --any --json"
    found = JSON.parse(shell_output(query))
    assert found["complete"]
    assert_equal %w[claude codex], found["results"].map { |hit| hit["provider"] }.sort
    found["results"].each { |hit| assert_match "--file", hit["follow_up"] }
    assert_equal found, JSON.parse(shell_output(query))

    ENV["CODEX_THREAD_ID"] = "brew-codex"
    current_query = "#{bin}/sxr find false --all-projects --json"
    assert_empty JSON.parse(shell_output(current_query, 1))["results"]
    restored = JSON.parse(shell_output("#{current_query} --include-current"))
    assert_equal "brew-codex", restored["results"][0]["id"]

    system bin/"sxr", "index", "--clear"
    refute_path_exists testpath/"cache/search.sqlite3"
  end
end
