import Foundation

var failures = 0

func check(_ condition: Bool, _ message: String) {
  if !condition {
    failures += 1
    fputs("FAIL: \(message)\n", stderr)
  }
}

func checkEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String) {
  check(actual == expected, "\(message): expected \(expected), got \(actual)")
}

runPrayerTests()
runUpdateTests()
runMediaTests()
runMediaSelectionTests()
runBatteryTests()
runAudioTests()
runGeometryTests()
runDefaultsTests()
runAIAgentTests()

if failures > 0 {
  fputs("\(failures) test(s) failed\n", stderr)
  exit(1)
}
print("All tests passed.")
