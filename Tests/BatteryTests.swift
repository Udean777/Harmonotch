import Foundation

func runBatteryTests() {
  // MARK: - Clamshell policy

  checkEqual(
    ClamshellPolicy.state(
      isArmed: false, hasExternalDisplay: true, isPluggedIn: true, batteryCapacity: 100
    ), .off, "unarmed is off")

  checkEqual(
    ClamshellPolicy.state(
      isArmed: true, hasExternalDisplay: false, isPluggedIn: true, batteryCapacity: 100
    ), .standby, "no external display is standby")

  checkEqual(
    ClamshellPolicy.state(
      isArmed: true, hasExternalDisplay: true, isPluggedIn: true, batteryCapacity: 10
    ), .active, "charging stays active")

  checkEqual(
    ClamshellPolicy.state(
      isArmed: true, hasExternalDisplay: true, isPluggedIn: false, batteryCapacity: 51
    ), .active, "on battery above cutoff is active")

  checkEqual(
    ClamshellPolicy.state(
      isArmed: true, hasExternalDisplay: true, isPluggedIn: false, batteryCapacity: 50
    ), .pausedLowBattery, "on battery at cutoff pauses")

  checkEqual(
    ClamshellPolicy.parseSleepDisabled(
      "System-wide power settings:\n SleepDisabled\t\t1\nCurrently in use:\n"),
    true,
    "parses SleepDisabled 1 with tabs"
  )
  checkEqual(
    ClamshellPolicy.parseSleepDisabled(
      "System-wide power settings:\n SleepDisabled      0\nCurrently in use:\n"),
    false,
    "parses SleepDisabled 0 with spaces"
  )
  checkEqual(
    ClamshellPolicy.parseSleepDisabled("Currently in use:\n sleep 1\n"),
    nil,
    "returns nil when SleepDisabled is absent"
  )

  // MARK: - Clamshell lid sleep support

  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: false, systemAllowsSleep: true, assertions: []),
    false,
    "lid false -> false"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: nil, systemAllowsSleep: true, assertions: []),
    false,
    "lid nil -> false"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true, systemAllowsSleep: false, assertions: []),
    false,
    "system policy false -> false"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true, systemAllowsSleep: nil, assertions: []),
    false,
    "system policy nil -> false"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true,
      systemAllowsSleep: true,
      assertions: [["AssertType": "DisplayWake", "ProcessingHotPlug": true, "AssertLevel": 255]]
    ),
    false,
    "ProcessingHotPlug assertion blocks sleep"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true,
      systemAllowsSleep: true,
      assertions: [
        ["AssertType": "PreventSystemSleep", "AppliesOnLidClose": true, "AssertLevel": 255]
      ]
    ),
    false,
    "AppliesOnLidClose assertion blocks sleep"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true,
      systemAllowsSleep: true,
      assertions: [["AssertType": "PreventUserIdleSystemSleep", "AssertLevel": 255]]
    ),
    true,
    "PreventUserIdleSystemSleep without lid flag allows sleep"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true,
      systemAllowsSleep: true,
      assertions: [
        ["AssertType": "PreventSystemSleep", "AppliesOnLidClose": true, "AssertLevel": 0]
      ]
    ),
    true,
    "assertion with AssertLevel 0 allows sleep"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true,
      systemAllowsSleep: true,
      assertions: [
        [
          "AssertType": "UserIsActive", "AppliesOnLidClose": NSNumber(value: 1),
          "AssertLevel": NSNumber(value: 255),
        ]
      ]
    ),
    false,
    "UserIsActive with NSNumber AppliesOnLidClose=1 blocks sleep"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true,
      systemAllowsSleep: true,
      assertions: [
        [
          "AssertType": "UserIsActive", "AppliesOnLidClose": NSNumber(value: 0),
          "AssertLevel": NSNumber(value: 255),
        ]
      ]
    ),
    true,
    "UserIsActive without lid flag allows sleep"
  )
  checkEqual(
    ClamshellLidSupport.shouldRequestSleep(
      lidClosed: true,
      systemAllowsSleep: true,
      assertions: nil
    ),
    true,
    "nil assertions when lid closed and system allows sleep returns true"
  )

  // MARK: - Charge Limit Policy Tests (100% Unrestricting)
  checkEqual(ChargeLimitPolicy.isLimitActive(threshold: 100), false, "Limit is not active at 100%")
  checkEqual(ChargeLimitPolicy.isLimitActive(threshold: 80), true, "Limit is active at 80%")
  checkEqual(ChargeLimitPolicy.clampThreshold(100), 100, "Clamp threshold allows 100%")
  checkEqual(ChargeLimitPolicy.clampThreshold(105), 100, "Clamp threshold caps at 100%")
  checkEqual(
    ChargeLimitPolicy.shouldInhibit(
      capacity: 85,
      isPluggedIn: true,
      isEnabled: false,
      targetThreshold: 100,
      currentlyInhibited: true
    ),
    false,
    "shouldInhibit is false when limit is set to 100%"
  )
  checkEqual(
    ChargeLimitPolicy.shouldInhibit(
      capacity: 80,
      isPluggedIn: true,
      isEnabled: true,
      targetThreshold: 80,
      currentlyInhibited: false
    ),
    true,
    "shouldInhibit is true when capacity hits threshold"
  )

  // MARK: - ChargeLimitPolicy.needsRestore (Fase 2.3)

  checkEqual(
    ChargeLimitPolicy.needsRestore(currentlyInhibited: false, shouldInhibit: false),
    false,
    "No restore needed when not inhibited and shouldInhibit is false"
  )
  checkEqual(
    ChargeLimitPolicy.needsRestore(currentlyInhibited: true, shouldInhibit: false),
    true,
    "Restore needed when currently inhibited and shouldInhibit becomes false"
  )
  checkEqual(
    ChargeLimitPolicy.needsRestore(currentlyInhibited: true, shouldInhibit: true),
    false,
    "No restore needed when staying inhibited"
  )
  checkEqual(
    ChargeLimitPolicy.needsRestore(currentlyInhibited: false, shouldInhibit: true),
    false,
    "No restore needed when transitioning into inhibit"
  )

  // MARK: - BatteryPresentation (Fase 3.4)

  checkEqual(
    BatteryPresentation.iconName(capacity: 95, isCharging: true), "battery.100.bolt",
    "charging >= 90 uses bolt")
  checkEqual(
    BatteryPresentation.iconName(capacity: 90, isCharging: true), "battery.100.bolt",
    "charging == 90 uses bolt")
  checkEqual(
    BatteryPresentation.iconName(capacity: 89, isCharging: true), "battery.75",
    "charging 89 uses battery.75")
  checkEqual(
    BatteryPresentation.iconName(capacity: 90, isCharging: false), "battery.75",
    "not charging 90 uses battery.75")
  checkEqual(
    BatteryPresentation.iconName(capacity: 60, isCharging: false), "battery.75",
    "60 uses battery.75")
  checkEqual(
    BatteryPresentation.iconName(capacity: 59, isCharging: false), "battery.50",
    "59 uses battery.50")
  checkEqual(
    BatteryPresentation.iconName(capacity: 35, isCharging: false), "battery.50",
    "35 uses battery.50")
  checkEqual(
    BatteryPresentation.iconName(capacity: 34, isCharging: false), "battery.25",
    "34 uses battery.25")
  checkEqual(
    BatteryPresentation.iconName(capacity: 10, isCharging: false), "battery.25",
    "10 uses battery.25")
  checkEqual(
    BatteryPresentation.iconName(capacity: 9, isCharging: false), "battery.0",
    "9 uses battery.0")
  checkEqual(
    BatteryPresentation.iconName(capacity: 0, isCharging: false), "battery.0",
    "0 uses battery.0")
}
