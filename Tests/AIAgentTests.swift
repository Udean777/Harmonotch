import Foundation

func runAIAgentTests() {
  // 1. DashboardTab includes .agents
  check(DashboardTab.allCases.contains(.agents), "DashboardTab.allCases should include .agents")
  checkEqual(DashboardTab.agents.icon, "cpu.fill", "DashboardTab.agents icon")
  checkEqual(DashboardTab.agents.defaultLabel, "AI Agent", "DashboardTab.agents defaultLabel")

  // 2. AIAgentAuthStatus behavior
  let authSuccess = AIAgentAuthStatus.authenticated(detail: "OAuth")
  let authFailed = AIAgentAuthStatus.failed(reason: "Not logged in")
  check(authSuccess.isAuthenticated, "authenticated status should report isAuthenticated == true")
  check(!authFailed.isAuthenticated, "failed status should report isAuthenticated == false")

  // 3. AIAgentDiscoveryService version parsing & path abbreviation
  checkEqual(
    AIAgentDiscoveryService.parseCleanVersion("2.1.104 (Claude Code)"),
    "2.1.104",
    "parseCleanVersion extracts semver from Claude output"
  )
  checkEqual(
    AIAgentDiscoveryService.parseCleanVersion("1.14.18"),
    "1.14.18",
    "parseCleanVersion extracts plain version"
  )
  checkEqual(
    AIAgentDiscoveryService.abbreviateHome("/Users/tester/.local/bin/claude", home: "/Users/tester"),
    "~/.local/bin/claude",
    "abbreviateHome replaces user home prefix with ~"
  )

  // 4. Temp directory tests for unauthenticated -> Failed status
  let tempHome = FileManager.default.temporaryDirectory
    .appendingPathComponent("harmonotch-aiagent-tests-\(UUID().uuidString)")
  try? FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
  defer {
    try? FileManager.default.removeItem(at: tempHome)
  }

  let codexAuthEmpty = AIAgentDiscoveryService.checkCodexAuth(home: tempHome.path)
  check(!codexAuthEmpty.isLoggedIn, "Missing ~/.codex/auth.json must report not logged in (Failed)")

  let opencodeAuthEmpty = AIAgentDiscoveryService.checkOpenCodeAuth(home: tempHome.path)
  check(opencodeAuthEmpty.isEmpty, "Missing ~/.local/share/opencode/auth.json must report empty providers (Failed)")

  let geminiAuthEmpty = AIAgentDiscoveryService.checkGeminiAuth(home: tempHome.path)
  check(!geminiAuthEmpty.isLoggedIn, "Missing Antigravity OAuth token must report not logged in (Failed)")

  let copilotAuthEmpty = AIAgentDiscoveryService.checkCopilotAuth(home: tempHome.path)
  check(!copilotAuthEmpty, "Missing gh hosts.yml must report not logged in (Failed)")

  // 5. Antigravity active model reading test
  let agyDir = tempHome.appendingPathComponent(".gemini/antigravity-cli")
  try? FileManager.default.createDirectory(at: agyDir, withIntermediateDirectories: true)
  let settingsFile = agyDir.appendingPathComponent("settings.json")
  let dummySettings = "{\"model\": \"Gemini 4 Argon (Medium)\"}"
  try? dummySettings.write(to: settingsFile, atomically: true, encoding: .utf8)

  let activeModel = AIAgentDiscoveryService.readGeminiActiveModel(home: tempHome.path)
  checkEqual(activeModel, "Gemini 4 Argon (Medium)", "readGeminiActiveModel should extract model from settings.json")

  // 6. Codex config test
  let codexDir = tempHome.appendingPathComponent(".codex")
  try? FileManager.default.createDirectory(at: codexDir, withIntermediateDirectories: true)
  let codexToml = codexDir.appendingPathComponent("config.toml")
  let dummyToml = """
model = "gpt-6-luna"
model_reasoning_effort = "high"
service_tier = "default"
"""
  try? dummyToml.write(to: codexToml, atomically: true, encoding: .utf8)
  let codexCfg = AIAgentDiscoveryService.readCodexConfig(home: tempHome.path)
  checkEqual(codexCfg.model, "gpt-6-luna", "readCodexConfig extracts model")
  checkEqual(codexCfg.effort, "high", "readCodexConfig extracts effort")
  checkEqual(codexCfg.tier, "default", "readCodexConfig extracts tier")

  // 7. Claude config test
  let claudeDir = tempHome.appendingPathComponent(".claude")
  try? FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
  let claudeSettings = claudeDir.appendingPathComponent("settings.json")
  let dummyClaude = """
{
  "env": {
    "ANTHROPIC_MODEL": "deepseek-v4-flash[1m]",
    "ANTHROPIC_BASE_URL": "https://api.deepseek.com/anthropic"
  },
  "modelSettings": {
    "deepseek-v4-flash": { "effortLevel": "low" }
  }
}
"""
  try? dummyClaude.write(to: claudeSettings, atomically: true, encoding: .utf8)
  let claudeCfg = AIAgentDiscoveryService.readClaudeConfig(home: tempHome.path)
  checkEqual(claudeCfg.model, "deepseek-v4-flash[1m]", "readClaudeConfig extracts model")
  checkEqual(claudeCfg.effort, "low", "readClaudeConfig extracts effort")
  checkEqual(claudeCfg.provider, "DeepSeek (api.deepseek.com)", "readClaudeConfig formats deepseek provider")

  // 8. OpenCode config test
  let opencodeDir = tempHome.appendingPathComponent(".config/opencode")
  try? FileManager.default.createDirectory(at: opencodeDir, withIntermediateDirectories: true)
  let opencodeJsonc = opencodeDir.appendingPathComponent("opencode.jsonc")
  let dummyOpencode = """
{
  "provider": {
    "9router": {
      "models": {
        "ag/claude-opus-4-6-thinking": { "name": "Opus 4.6 Thinking" },
        "cx/gpt-6-astra": { "name": "GPT 6 Astra" }
      }
    }
  }
}
"""
  try? dummyOpencode.write(to: opencodeJsonc, atomically: true, encoding: .utf8)
  let opencodeCfg = AIAgentDiscoveryService.readOpenCodeConfig(home: tempHome.path)
  check(opencodeCfg.models.contains("Opus 4.6 Thinking"), "readOpenCodeConfig contains Opus 4.6 Thinking")
  check(opencodeCfg.models.contains("GPT 6 Astra"), "readOpenCodeConfig contains GPT 6 Astra")

  // 9. Localization
  check(!L10n.AIAgents.activeModelLabel.isEmpty, "L10n.AIAgents.activeModelLabel should not be empty")
  check(!L10n.AIAgents.detailQuotaTitle.isEmpty, "L10n.AIAgents.detailQuotaTitle should not be empty")
  check(!L10n.AIAgents.providerLabel.isEmpty, "L10n.AIAgents.providerLabel should not be empty")
  check(!L10n.AIAgents.configuredModels.isEmpty, "L10n.AIAgents.configuredModels should not be empty")
}
