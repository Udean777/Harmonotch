import Foundation

func runUpdateTests() {
  // MARK: - Version

  checkEqual(Version.isNewer("1.2.3", than: "1.2.2"), true, "patch bump")
  checkEqual(Version.isNewer("1.10.0", than: "1.9.9"), true, "numeric, not lexical")
  checkEqual(Version.isNewer("1.2", than: "1.2.0"), false, "missing components are zero")
  checkEqual(Version.isNewer("2.0.0-beta", than: "1.9.0"), true, "prerelease suffix ignored")
  checkEqual(Version.isNewer("v1.3.0", than: "1.2.9"), true, "leading v")

  // Version Comparable & Hashable
  checkEqual(Version("1.2.3") > Version("1.2.2"), true, "Version > patch")
  checkEqual(Version("1.2") == Version("1.2.0"), true, "Version == trailing zero")
  checkEqual(Version("2.0.0-beta") > Version("1.9.0"), true, "Version > with prerelease")
  checkEqual(Version("v1.3.0") == Version("1.3.0"), true, "Version == leading v")
  checkEqual(
    Set([Version("1.2"), Version("1.2.0")]).count, 1, "Version Set deduplication via Hashable")

  // MARK: - UpdateInstallerSupport

  checkEqual(
    UpdateInstallerSupport.progressStepAdvanced(from: nil, to: 0.05), true,
    "first progress always advances")
  checkEqual(
    UpdateInstallerSupport.progressStepAdvanced(from: 0.121, to: 0.129), false,
    "sub-percent step doesn't advance")
  checkEqual(
    UpdateInstallerSupport.progressStepAdvanced(from: 0.129, to: 0.131), true,
    "crossing whole percent advances")
  checkEqual(
    UpdateInstallerSupport.downloadByteLimit(expectedBytes: 15_000_000), 15_000_000,
    "expected size within ceiling")
  checkEqual(
    UpdateInstallerSupport.downloadByteLimit(expectedBytes: 500_000_000),
    UpdateInstallerSupport.downloadCeilingBytes, "excessive size capped")
  checkEqual(
    UpdateInstallerSupport.downloadIsUsable(
      status: 200, receivedBytes: 15_000_000, expectedBytes: 15_000_000), true,
    "matching size usable")
  checkEqual(
    UpdateInstallerSupport.downloadIsUsable(
      status: 404, receivedBytes: 15_000_000, expectedBytes: 15_000_000), false,
    "non-200 unusable")
  checkEqual(
    UpdateInstallerSupport.shellSingleQuoted("test'app"), "'test'\\''app'",
    "shell single quoting")
  checkEqual(
    UpdateInstallerSupport.runsFromImmutableLocation(
      appPath: "/AppTranslocation/d/app.app", volumeIsReadOnly: { _ in false }), true,
    "app translocation detected")
  checkEqual(
    UpdateInstallerSupport.runsFromImmutableLocation(
      appPath: "/Applications/Harmonotch.app", volumeIsReadOnly: { _ in false }), false,
    "normal app location")
}
