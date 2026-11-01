# Acknowledgements & Open Source Credits

Harmonotch uses the open-source projects and assets listed below. Thanks to their authors and maintainers.

---

## 1. Adhan-Swift

- **Author / Organization:** [Batoul Apps](https://github.com/batoulapps)
- **Repository:** [https://github.com/batoulapps/adhan-swift](https://github.com/batoulapps/adhan-swift)
- **License:** MIT License
- **Purpose in Harmonotch:** Powers astronomical prayer calculations, sunnah times, solar coordinates, and Qibla calculations completely on-device without external API calls.

```text
Copyright © 2018 Batoul Apps. All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
```

---

## 2. Adzan Audio Recordings

- **Source:** [IslamDownload.net](https://islamdownload.net/123801-download-suara-adzan.html)
- **Files:** `adzan.m4a` (Standard Adzan) & `adzan_subuh.m4a` (Fajr Adzan with Tathweeb)
- **Format:** AAC 48 kHz
- **Purpose in Harmonotch:** High-fidelity call to prayer audio playback integrated with local notifications.

---

## 3. Vorssaint (MediaRemote Bridge Approach)

- **Author:** [Vorssaint](https://github.com/vorssaint)
- **Repository:** [https://github.com/vorssaint/vorssaint-utils](https://github.com/vorssaint/vorssaint-utils)
- **License:** GNU General Public License v3.0 (GPL-3.0)
- **Purpose in Harmonotch:** The now-playing bridge loads a small adapter into `/usr/bin/perl` and talks to Apple's private MediaRemote framework from there, an approach demonstrated by Vorssaint. It is used with the author's written permission and with credit. The files in this repository (`NowPlayingAdapter.m`, `nowplaying.pl`, and `NowPlayingBridge.swift`) are an independent implementation; no Vorssaint source code was copied, so Harmonotch remains MIT-licensed.

---

## 4. LRCLIB (Synced Lyrics Engine)

- **Source:** [LRCLIB](https://lrclib.net)
- **Repository:** [https://github.com/tranxuanthang/lrclib](https://github.com/tranxuanthang/lrclib)
- **License:** Open Source / Free Community API
- **Purpose in Harmonotch:** Powers the real-time karaoke synced lyrics fetcher and time-synchronized lyric scroller.

---

## 5. Apple Inc. Technologies

- **SF Symbols:** Apple Inc. Human Interface Guidelines and native macOS system iconography.
- **MediaRemote & IOKit (`AppleSmartBattery`):** Darwin / Apple system frameworks for real-time media remote transport and direct, daemon-free hardware battery health telemetry. Harmonotch's MediaRemote adapter is written from scratch (see the Vorssaint credit above) and uses the framework's undocumented symbols at runtime; no third-party bridge code is included.

---

_Thank you to all contributors and open-source maintainers worldwide._
