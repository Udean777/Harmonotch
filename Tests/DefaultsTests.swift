import Foundation

func runDefaultsTests() {
  // MARK: - UserDefaultsKey

  let defaults = UserDefaults.standard
  let testKey = UserDefaultsKey<Int>("typeSafetyTestKey", defaultValue: 99)
  defaults.remove(testKey)
  checkEqual(defaults[testKey], 99, "UserDefaultsKey defaultValue when unset")
  defaults[testKey] = 42
  checkEqual(defaults[testKey], 42, "UserDefaultsKey stored value")
  checkEqual(defaults.contains(testKey), true, "UserDefaults.contains stored key")
  defaults.remove(testKey)
  checkEqual(defaults[testKey], 99, "UserDefaultsKey restored to defaultValue after removal")

  // MARK: - TimeFormatting (Fase 3.7)

  checkEqual(TimeFormatting.clock(0), "0:00", "clock 0s")
  checkEqual(TimeFormatting.clock(-5), "0:00", "clock negative clamps to 0:00")
  checkEqual(TimeFormatting.clock(65), "1:05", "clock 1m5s")
  checkEqual(TimeFormatting.clock(3661, includeHours: true), "1:01:01", "clock 1h1m1s with hours")
  checkEqual(
    TimeFormatting.clock(3661, includeHours: false), "61:01", "clock 1h1m1s without hours")
}
