import Foundation

func runAudioTests() {
  // MARK: - SystemAudioService

  checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: false, direction: 1, fine: false),
    0.3125,
    "coarse volume step up (+1/16)"
  )
  checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: false, direction: -1, fine: false),
    0.1875,
    "coarse volume step down (-1/16)"
  )
  checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: false, direction: 1, fine: true),
    0.265625,
    "fine volume step up (+1/64)"
  )
  checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: true, direction: 1, fine: false),
    0.0625,
    "volume step up from muted starts at 0"
  )
  checkEqual(
    SystemAudioService.targetVolume(current: 0.25, muted: true, direction: -1, fine: false),
    0.0,
    "volume step down from muted stays at 0"
  )
  checkEqual(
    SystemAudioService.targetVolume(current: 0.98, muted: false, direction: 1, fine: false),
    1.0,
    "volume step up clamps at 1.0"
  )
  checkEqual(
    SystemAudioService.targetVolume(current: 0.02, muted: false, direction: -1, fine: false),
    0.0,
    "volume step down clamps at 0.0"
  )
  checkEqual(
    SystemAudioService.shouldAutoMute(forVolume: 0.0),
    true,
    "volume 0.0 triggers auto-mute"
  )
  checkEqual(
    SystemAudioService.shouldAutoMute(forVolume: 0.0625),
    false,
    "audible volume does not auto-mute"
  )
  checkEqual(
    SystemAudioService.readVolume(for: 0),
    nil,
    "invalid device ID returns nil volume"
  )
  checkEqual(
    SystemAudioService.writeVolume(0.5, for: 0),
    false,
    "invalid device ID writeVolume returns false"
  )
  checkEqual(
    SystemAudioService.readMute(for: 0),
    nil,
    "invalid device ID returns nil mute"
  )
  checkEqual(
    SystemAudioService.writeMute(true, for: 0),
    false,
    "invalid device ID writeMute returns false"
  )

  // MARK: - VolumeKeyRouter

  let volUp = VolumeMediaKey.volumeUp.rawValue
  let volDown = VolumeMediaKey.volumeDown.rawValue
  let muteKey = VolumeMediaKey.mute.rawValue
  let downState = VolumeKeyRouter.keyDownState
  let upState = VolumeKeyRouter.keyUpState

  do {
    // disabled -> pass-through
    var router = VolumeKeyRouter()
    checkEqual(
      router.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: false, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 10.0
      ),
      .passThrough,
      "disabled -> pass-through"
    )
  }

  do {
    // up without app-owned down -> pass-through
    var router = VolumeKeyRouter()
    checkEqual(
      router.handle(
        keyCode: volUp, state: upState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 10.0
      ),
      .passThrough,
      "up without app-owned down -> pass-through"
    )
  }

  do {
    // app-owned down then repeat then up -> step, step, consume
    var router = VolumeKeyRouter()
    checkEqual(
      router.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 10.0
      ),
      .step(1),
      "app-owned volume up key-down -> .step(1)"
    )
    checkEqual(
      router.handle(
        keyCode: volUp, state: downState, isRepeat: true,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 10.1
      ),
      .step(1),
      "app-owned volume up repeat -> .step(1)"
    )
    checkEqual(
      router.handle(
        keyCode: volUp, state: upState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 10.2
      ),
      .consume,
      "app-owned key-up -> .consume"
    )
    checkEqual(
      router.handle(
        keyCode: volUp, state: upState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 10.3
      ),
      .passThrough,
      "second key-up after release -> .passThrough"
    )
  }

  do {
    // repeat before app-owned down -> pass-through
    var router = VolumeKeyRouter()
    checkEqual(
      router.handle(
        keyCode: volDown, state: downState, isRepeat: true,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 20.0
      ),
      .passThrough,
      "repeat without prior app-owned down -> pass-through"
    )
    checkEqual(router.blocksCustomHUD(21.0), true, "unowned repeat activates native window")
  }

  do {
    // Command, Control, Option alone -> pass-through; Option+Shift -> fine step
    var cmdRouter = VolumeKeyRouter()
    checkEqual(
      cmdRouter.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: true, now: 30.0
      ),
      .passThrough,
      "Command/Control + volume -> pass-through"
    )

    var optRouter = VolumeKeyRouter()
    checkEqual(
      optRouter.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: true, shift: false, commandOrControl: false, now: 30.0
      ),
      .passThrough,
      "Option alone + volume -> pass-through"
    )

    var fineRouter = VolumeKeyRouter()
    checkEqual(
      fineRouter.handle(
        keyCode: volDown, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: true, shift: true, commandOrControl: false, now: 30.0
      ),
      .step(-1),
      "Option+Shift + volume down -> .step(-1)"
    )
    checkEqual(VolumeKeyRouter.isFineStep(option: true, shift: true), true, "Option+Shift is fine step")
    checkEqual(VolumeKeyRouter.isFineStep(option: true, shift: false), false, "Option alone is not fine step")
  }

  do {
    // Output without software volume -> pass-through and window active;
    //    new press during window -> pass-through (extends window);
    //    press after window expires -> taken by app again.
    var router = VolumeKeyRouter()
    checkEqual(
      router.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: false, hasMute: false,
        option: false, shift: false, commandOrControl: false, now: 100.0
      ),
      .passThrough,
      "output without volume -> pass-through"
    )
    checkEqual(router.blocksCustomHUD(101.0), true, "native window is active after pass-through")
    checkEqual(router.nativeOwnsUntil, 101.6, "native window set to now + 1.6")

    // New press during active window (even if device now has volume) -> pass-through & extends window
    checkEqual(
      router.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 101.0
      ),
      .passThrough,
      "new press during native window -> pass-through"
    )
    checkEqual(router.nativeOwnsUntil, 102.6, "pass-through during window extends nativeOwnsUntil")

    // Key-up for that system-owned press -> pass-through
    checkEqual(
      router.handle(
        keyCode: volUp, state: upState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 101.1
      ),
      .passThrough,
      "key-up for system-owned press -> pass-through"
    )

    // Press after window expires (at 102.7 > 102.6) -> owned by app again
    checkEqual(
      router.handle(
        keyCode: volUp, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 102.7
      ),
      .step(1),
      "press after window expires -> owned by app"
    )
  }

  do {
    // Mute key: down -> .toggleMute, repeat -> .consume, up -> .consume
    var router = VolumeKeyRouter()
    checkEqual(
      router.handle(
        keyCode: muteKey, state: downState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 50.0
      ),
      .toggleMute,
      "mute key-down -> .toggleMute"
    )
    checkEqual(
      router.handle(
        keyCode: muteKey, state: downState, isRepeat: true,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 50.1
      ),
      .consume,
      "mute repeat -> .consume"
    )
    checkEqual(
      router.handle(
        keyCode: muteKey, state: upState, isRepeat: false,
        enabled: true, canHandle: true, hasVolume: true, hasMute: true,
        option: false, shift: false, commandOrControl: false, now: 50.2
      ),
      .consume,
      "mute key-up -> .consume"
    )
  }

  do {
    // Fallback markSystemOwnership clears held keys and sets window
    var router = VolumeKeyRouter()
    _ = router.handle(
      keyCode: volUp, state: downState, isRepeat: false,
      enabled: true, canHandle: true, hasVolume: true, hasMute: true,
      option: false, shift: false, commandOrControl: false, now: 60.0
    )
    checkEqual(router.held.contains(volUp), true, "volUp held before fallback")
    router.markSystemOwnership(now: 60.05)
    checkEqual(router.held.isEmpty, true, "fallback clears held keys")
    checkEqual(router.blocksCustomHUD(61.0), true, "fallback activates native window")
  }

  // MARK: - Volume HUD localization, symbols and defaults

  checkEqual(
    UserDefaultsKeys.volumeHUDEnabled.defaultValue,
    false,
    "volumeHUDEnabled defaults to false (opt-in)"
  )
  checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.4, muted: true),
    "speaker.slash.fill",
    "muted symbol is speaker.slash.fill"
  )
  checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.0, muted: false),
    "speaker.slash.fill",
    "zero level symbol is speaker.slash.fill"
  )
  checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.2, muted: false),
    "speaker.wave.1.fill",
    "low volume symbol is speaker.wave.1.fill"
  )
  checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.5, muted: false),
    "speaker.wave.2.fill",
    "medium volume symbol is speaker.wave.2.fill"
  )
  checkEqual(
    VolumeKeyRouter.volumeSymbol(level: 0.85, muted: false),
    "speaker.wave.3.fill",
    "high volume symbol is speaker.wave.3.fill"
  )

  let savedLang = LanguageManager.shared.currentLanguage
  LanguageManager.shared.setLanguage(.indonesian)
  checkEqual(
    L10n.Volume.accessibilityLabel(percent: 40, muted: false),
    "Volume 40 persen",
    "Indonesian accessibility label for 40% volume"
  )
  checkEqual(
    L10n.Menu.volumeHUDToggle,
    "Volume HUD di Notch",
    "Indonesian menu toggle title"
  )
  LanguageManager.shared.setLanguage(.english)
  checkEqual(
    L10n.Volume.accessibilityLabel(percent: 40, muted: false),
    "Volume 40 percent",
    "English accessibility label for 40% volume"
  )
  LanguageManager.shared.setLanguage(savedLang)

  // Feedback clicks parity with macOS
  checkEqual(
    VolumeKeyRouter.playsFeedback(setting: true, option: false, shift: false), true,
    "feedback true: normal click")
  checkEqual(
    VolumeKeyRouter.playsFeedback(setting: true, option: false, shift: true), false,
    "feedback true: Shift inverts to false")
  checkEqual(
    VolumeKeyRouter.playsFeedback(setting: true, option: true, shift: true), true,
    "feedback true: Option+Shift keeps setting")
  checkEqual(
    VolumeKeyRouter.playsFeedback(setting: false, option: false, shift: false), false,
    "feedback false: normal no click")
  checkEqual(
    VolumeKeyRouter.playsFeedback(setting: false, option: false, shift: true), true,
    "feedback false: Shift inverts to click")
  checkEqual(
    VolumeKeyRouter.playsFeedback(setting: false, option: true, shift: true), false,
    "feedback false: Option+Shift keeps setting")
}
