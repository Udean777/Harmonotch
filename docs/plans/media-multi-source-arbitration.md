# Plan: Media Manager Multi-Source Arbitration (Semua App Audio)

Status: draft
Tanggal: 2026-11-07
Target: `/Users/ssajudn/projects/Harmonotch`
Referensi hasil reverse engineering: `/Users/ssajudn/projects/vorssaint-utils`

## Tujuan

Media manager menampilkan dan mengendalikan **satu sumber audio yang benar**
ketika beberapa app memutar audio bersamaan — bukan hanya Spotify dan YouTube,
tetapi app apa pun yang bisa mengeluarkan suara: Music, Podcasts, VLC, IINA,
QuickTime, browser, Zoom, Teams, game, dan helper process di belakangnya.

Aturan intinya:

1. Hanya ada **satu arbiter**. Produsen metadata hanya mengirim kandidat.
2. **Paused tidak pernah mengalahkan playing**, dari app mana pun.
3. Sumber dikenali dari **identitas app/proses**, bukan enum nama app.
4. Kalau metadata tidak tersedia, UI tetap menampilkan app yang memutar audio
   sebagai kartu `audioOnly`, tanpa berpura-pura punya judul/cover.

## Non-goals

- Tidak membaca isi audio atau melakukan speech/audio recognition.
- Tidak membuat mixer per-app.
- Tidak mengubah Lyrics/LRCLIB.
- Tidak menjamin metadata untuk app yang tidak mendaftar Now Playing dan tidak
  scriptable. Untuk app seperti itu, yang ditampilkan hanya nama + ikon app.
- Tidak mengubah perilaku AdzanPlayer.

## Bug yang dilaporkan

Contoh: Spotify di-pause saat YouTube sedang playing.

- UI tetap menampilkan Spotify (paused), padahal YouTube yang berbunyi.
- Kadang judul dan durasi sudah berganti, tetapi thumbnail tetap cover lama.

Bug ini bukan khusus Spotify/YouTube. Kombinasi app apa pun dengan pola yang
sama akan menghasilkan gejala yang sama.

## Bukti di kode saat ini

### 1. Tidak ada arbiter; penulis terakhir menang

- `Harmonotch/Features/Media/MediaManager.swift:265-291`
  `handleSpotifyNotification` langsung memanggil `updateTrack(source: .spotify, ...)`
  tanpa memeriksa apakah Spotify masih menjadi sumber aktif.
- `:292-318` `handleAppleMusicNotification` melakukan hal yang sama.
- `:368-400` `handleNowPlayingState` langsung memakai state bridge.
- `:728-767` `applyWebSnapshot` langsung memakai snapshot browser.

Semua jalur menulis ke `@Published` yang sama. Notifikasi pause dari app yang
tidak sedang tampil tetap mengganti UI.

### 2. Bridge menghentikan polling

`MediaManager.swift:518-521`:

```swift
if nowPlayingBridge.isAvailable && hasActiveTrack { return }
```

Begitu ada track apa pun — termasuk player yang paused — polling AppleScript
berhenti. Jalur yang bisa menemukan browser yang sedang playing tidak pernah
dijalankan.

### 3. Bridge hanya membaca system player

`NowPlayingAdapter.m` memakai `MRMediaRemoteGetNowPlayingInfo` dan
`MRMediaRemoteGetNowPlayingApplicationDisplayID`. MediaRemote menyimpan satu
"system now playing"; player yang paused masih bisa menjadi pemiliknya.
Adapter tidak membaca state semua client sekaligus.

### 4. Model sumber kaku

- `MediaSource` (`MediaManager.swift:7-42`) adalah daftar app tetap.
- `mediaSource(for:)` (`:402-415`) tidak pernah menghasilkan `.iina` atau
  `.vlc`; app tak dikenal menjadi `.system` dan kehilangan identitas.
- Hanya Spotify dan Apple Music yang punya poller AppleScript (`:532-604`),
  hanya browser yang punya probe JS (`:652`). App lain bergantung pada bridge.

### 5. Thumbnail tidak berganti

- `updateTrack` hanya memanggil `fetchArtworkAsync` saat track berubah
  (`:337-347`).
- `fetchArtworkAsync` (`:1020-1078`) hanya punya cabang `.spotify` dan
  `.appleMusic`. Untuk `.safari`/`.web` tanpa `directURL`, fungsi tidak
  melakukan apa pun, jadi cover lama tertinggal.
- Cover lama tidak dikosongkan saat identitas track berubah.
- Hasil request async tidak dicek terhadap track yang sedang aktif; cover lama
  yang selesai belakangan bisa menimpa cover baru.
- Adapter memakai key artwork `title|artist|album` tanpa `displayID`
  (`NowPlayingAdapter.m`), sehingga pergantian app dengan metadata sama tidak
  memicu artwork baru.

### 6. Command pergi ke player yang salah

`playPause()`, `nextTrack()`, `seek()` (`MediaManager.swift:920-963`) selalu
lewat bridge ke system player. Kalau UI menampilkan app B sementara system
player masih app A, tombol mengendalikan A.

## Yang dilakukan Vorssaint

Vorssaint tidak memakai satu stream system now-playing. Adapternya:

- Mengenumerasi semua client (`MRMediaRemoteGetNowPlayingClients`).
- Membaca info dan state per player (`MRMediaRemoteGetNowPlayingInfoForPlayer`,
  `MRMediaRemoteGetPlaybackStateForPlayer`).
- Mengirim command ke player path pilihan (`MRMediaRemoteSendCommandToPlayer`).

Urutan pemilihan di `Sources/Vorssaint/Services/Notch/NotchPlaybackSource.swift`
(`preferred`):

1. Pilihan manual user.
2. Music app yang playing.
3. Player lain yang playing.
4. Player yang sebelumnya tampil, meskipun paused.
5. System player sebagai tie-break.
6. Sisanya.

Harmonotch belum punya lapisan ini. Yang perlu diambil adalah **model seleksinya**,
bukan kode GPL-nya.

---

## Arsitektur target

```
MediaRemote clients ─┐
AppleScript poller  ─┤
Browser JS probe    ─┼─► MediaCandidate registry ─► MediaSelector ─► MediaPresentation ─► UI
CoreAudio presence  ─┘                                      │
                                                             └─► Control adapter
```

### 1. MediaCandidate

Satu kandidat mewakili satu app/proses yang punya sesi audio.

```swift
struct MediaCandidate: Equatable {
  var identity: MediaIdentity      // bundleID + pid + contentID/item
  var app: MediaAppInfo            // bundleID, displayName, icon, category
  var title: String
  var artist: String
  var album: String
  var duration: Double
  var position: Double
  var isPlaying: Bool
  var hasMetadata: Bool            // title tidak kosong
  var isMusicApp: Bool             // dari kategori app, bukan daftar hardcode
  var artwork: MediaArtworkSource? // data, URL, atau nil
  var awareness: Awareness         // .mediaRemote, .script, .presence
  var lastUpdated: TimeInterval
}
```

`identity` tidak boleh hanya title+artist. YouTube dan Spotify bisa memutar lagu
yang sama; keduanya harus tetap kandidat berbeda.

### 2. MediaSelector (pure, bisa dites)

```swift
static func select(_ candidates: [MediaCandidate],
                   previous: MediaIdentity?,
                   system: MediaIdentity?,
                   userSelection: MediaIdentity?) -> MediaCandidate?
```

Urutan:

1. `userSelection` yang masih punya track.
2. Kandidat playing dengan metadata; music app lebih dulu.
3. Kandidat playing tanpa metadata (presence).
4. `previous` jika masih punya sesi (paused sticky).
5. `system` sebagai tie-break.
6. Kandidat lain yang punya metadata.

Aturan tambahan:

- Kandidat paused tidak pernah mengalahkan kandidat playing.
- Kandidat dengan `confidence` rendah (presence < debounce) tidak masuk.
- Jika dua kandidat playing dan sama-sama bukan music app, pilih yang mulai
  playing lebih dulu; jika seri, app frontmost.

### 3. MediaPresentation

UI tidak membaca kandidat mentah.

```swift
struct MediaPresentation: Equatable {
  enum Kind: Equatable {
    case track(TrackInfo)        // metadata lengkap
    case audioOnly(AppInfo)      // app mengeluarkan audio tanpa metadata
  }
  var kind: Kind
  var isPlaying: Bool
  var capabilities: MediaCapabilities
}
```

`MediaCapabilities` berisi `.playPause`, `.skip`, `.seek`, `.openApp`.
Tombol digambar berdasarkan capability, bukan `switch mediaSource`.

### 4. MediaAppInfo

- `bundleID`, `displayName` dari `NSRunningApplication.localizedName`.
- `icon` dari `NSWorkspace.shared.icon(forFile:)`, fallback SF Symbol.
- `category` dari bundle (`public.app-category.music`, `.video`, dll.) untuk
  tie-break, bukan untuk whitelist.

---

## Discovery generik

### Lapis 1 — MediaRemote clients

- Enumerasi semua client yang terdaftar.
- Baca info + state per player.
- Ini mencakup app yang mendaftar Now Playing: Spotify, Music, Podcasts, IINA,
  VLC, QuickTime, browser, dan app pihak ketiga lain.

### Lapis 2 — CoreAudio presence

Untuk app yang memutar audio tanpa mendaftar Now Playing (Zoom, Teams, game,
voice note, helper):

- `kAudioHardwarePropertyProcessObjectList` pada system object.
- Per proses: `kAudioProcessPropertyPID`, `kAudioProcessPropertyBundleID`,
  `kAudioProcessPropertyIsRunningOutput`.
- Listener property, bukan polling.
- Target deployment Harmonotch saat ini macOS 14.0. Verifikasi ketersediaan API
  process object saat implementasi; kalau tidak tersedia, fallback ke
  MediaRemote-only.

### Lapis 3 — Script/JS (opsional, untuk kontrol & metadata)

- AppleScript: Spotify, Music, QuickTime.
- JS: browser.
- Sifatnya capability adapter, bukan penentu seleksi.

---

## Hardening deteksi presence

### 1. Debounce dan hysteresis

- Kandidat dianggap playing setelah `IsRunningOutput == true` terus-menerus
  **1.5 detik**.
- Dianggap berhenti setelah **3 detik** false.
- Konstanta di satu tempat.
- Tujuan: notifikasi sistem, klik UI, atau efek singkat tidak memunculkan kartu.

### 2. Resolusi PID ke app yang bertanggung jawab

1. Bundle ID proses → `NSRunningApplication` dengan bundle `.app` → pakai.
2. Jika helper (WebKit GPU/WebContent, Chromium Helper, Electron helper),
   telusuri parent PID lewat `sysctl(KERN_PROC_PID)` maksimal 4 level sampai
   menemukan proses dengan bundle `.app`.
3. Jika gagal, turunkan dari path executable: cari komponen `.app` terdekat.
4. Jika tidak ada app bundle → abaikan (menyaring daemon sistem).

Contoh: `com.apple.WebKit.GPU` di bawah Safari harus merge menjadi kandidat
`com.apple.Safari`. Audio presence lalu memperkuat kandidat metadata browser,
bukan membuat kartu terpisah.

### 3. Exclude dan merge

- Exclude PID Harmonotch sendiri, daemon audio sistem, dan proses tanpa app.
- Merge berdasarkan bundle ID app yang bertanggung jawab.
- Presence hanya menandai `isPlaying`; metadata tetap dari MediaRemote/adaptor.
- Jika metadata dan presence untuk app yang sama, metadata menang untuk tampilan.

### 4. App panggilan

Zoom/Teams tetap tampil sebagai `audioOnly` karena memang mengeluarkan audio.
Sediakan setting "Sertakan app audio lain":

- ON (default): semua app yang memutar audio boleh tampil.
- OFF: hanya app yang punya metadata/MediaRemote.

### 5. Batas yang harus jujur di UI

Untuk `audioOnly`, Harmonotch tidak tahu judul, durasi, atau posisi. Jangan
tampilkan progress atau tombol yang tidak bisa dilakukan. Kontrol hanya
"Buka App", plus play/pause kalau MediaRemote per-player mengizinkannya.

---

## UI kartu generik

### Model kompatibilitas

Banyak call site memakai `hasActiveTrack`, `trackTitle`, dan
`mediaSource.rawValue`:

- `Harmonotch/App/AppDelegate.swift:98,130,567`
- `Harmonotch/NotchUI/NotchTab.swift:41`
- `Harmonotch/NotchUI/NotchContainerView.swift:17,65`
- `Harmonotch/NotchUI/NotchPillView.swift:20,49,197,308`
- `Harmonotch/NotchUI/NotchWindowController.swift:38,354`
- `Harmonotch/NotchUI/NotchViewModel.swift:53,64`
- `Harmonotch/Features/MenuBar/Sections/DashboardNowSection.swift:26,268`
- `Harmonotch/Features/Media/MediaDrawerView.swift:37,47,184-236`

Strategi migrasi:

- Tambah `@Published private(set) var presentation: MediaPresentation?`.
- Tambah `var hasMediaSession: Bool { presentation != nil }`.
- `hasActiveTrack` tetap berarti "ada metadata".
- `mediaSource` dipertahankan sebagai shim sementara; UI baru membaca
  `presentation.app`.
- Setelah semua call site pindah, hapus `MediaSource` dan ganti dengan
  `MediaAppInfo`.

### Collapsed pill

`NotchPillView`:

- Thumbnail kiri: cover jika ada; jika `audioOnly`, ikon app dalam rounded tile
  dengan ukuran, corner radius, dan border yang sama seperti cover.
- Kanan: `EqualizerWaveformView` saat playing, `pause.fill` saat paused.
- Tidak ada judul di pill; tidak ada layout baru.
- Gate memakai `hasMediaSession`, bukan `hasActiveTrack`.

### Media drawer

`MediaDrawerView:184-300`:

- Tile 64×64: cover, atau ikon app dengan latar `AppTheme.badgeBackground`.
- Badge: ikon kecil + nama app (`Spotify`, `Zoom`, `IINA`, dst.).
- `audioOnly`:
  - Judul: `L10n.Media.audioPlaying` ("Sedang memutar audio").
  - Subjudul: nama app.
  - Progress bar, durasi, tombol lirik, prev/next: disembunyikan.
  - Tombol utama: "Buka <App>" memanggil `NSRunningApplication.activate`.
  - Play/pause tetap muncul hanya jika capability tersedia.
- `track`: tampilan sekarang, dengan ikon/nama dari `MediaAppInfo`.

### Menu bar dashboard

`DashboardNowSection`:

- Bentuk ringkas: ikon app + nama app + state.
- Tanpa kontrol transport jika capability tidak ada.
- Jangan memakai `mediaSource.rawValue`; pakai `presentation.app.displayName`.

### Aksesibilitas

- Label kartu `audioOnly`: "Zoom sedang memutar audio".
- Tombol "Buka Zoom" punya label yang jelas.
- Jangan mengumumkan "judul tidak tersedia" berulang kali.

### Localization

Tambah di `L10n.Media`:

- `audioPlaying`: "Sedang memutar audio" / "Audio playing".
- `openApp`: "Buka <App>" / "Open <App>".
- `includeOtherAudioApps`: label setting.

---

## Artwork

- Tambah `mediaGeneration` yang naik setiap `identity` berubah.
- `fetchArtworkAsync(generation:)`; hasil dengan generation basi dibuang.
- Saat identitas berubah dan belum ada cover baru, kosongkan artwork atau pakai
  placeholder; jangan pertahankan cover lama.
- Untuk sumber browser lewat bridge, jika `directArtwork == nil`, ambil
  `artworkURL` dari `activeWebTarget` atau `videoId` YouTube.
- `applyArtwork` hanya dipanggil untuk kandidat yang sedang aktif.
- Di adapter, masukkan `displayID` ke `artworkKey` agar pergantian app selalu
  memicu artwork baru.

---

## Command routing

Routing berbasis capability, bukan `switch mediaSource`:

- MediaRemote per-player path: app apa pun yang terdaftar dan mendukung command.
- AppleScript: hanya app yang punya adapter.
- JS: browser.
- Tidak ada adapter: sembunyikan tombol transport, sisakan "Buka App".

Pertahankan guard `lastCommandAt` dan `expectedPlayingState` supaya pembacaan
basi tidak membatalkan command. Command optimistis harus memperbarui kandidat
aktif, bukan system player.

---


## Phase 0 — Reproduksi dan instrumentasi

Tujuan: membuktikan urutan event sebelum mengubah arsitektur.

### Tasks

- [ ] Jalankan Spotify + YouTube (browser) bersamaan; catat urutan:
      state bridge, notifikasi Spotify, hasil poll browser.
- [ ] Ulangi dengan Music + Podcasts, dan VLC/IINA + browser.
- [ ] Tambahkan log sementara: producer, source, title, `isPlaying`, waktu.
- [ ] Catat apakah cover lama berasal dari cache, request terlambat, atau
      memang tidak ada fetch untuk sumber browser.

### Acceptance

- Terlihat jelas produsen mana yang menimpa UI dan kapan.

---

## Phase 1 — Discovery generik

### Tasks

- [ ] `MediaAppInfo` + resolver ikon/nama.
- [ ] Enumerasi MediaRemote clients (via adapter).
- [ ] CoreAudio process presence + listener + debounce + resolusi parent PID.
- [ ] Fungsi pure untuk merge kandidat dan aturan exclusion.
- [ ] Tes untuk resolusi helper → app induk dan debounce.

### Acceptance

- App audio tanpa metadata terdeteksi sebagai kandidat.
- Helper process tidak muncul sebagai app terpisah.
- Bunyi singkat <1.5 detik tidak menghasilkan kandidat.

---

## Phase 2 — Model dan selector

### Tasks

- [ ] `MediaCandidate`, `MediaIdentity`, `MediaCapabilities`,
      `MediaPresentation`.
- [ ] `MediaSelector.select` dengan urutan generik.
- [ ] Tes seleksi: playing vs paused, dua playing, dua paused, audio-only,
      metadata vs presence, user selection.

### Acceptance

- Selector lulus seluruh matriks tanpa AppKit/hardware.

---

## Phase 3 — Satu penulis

### Tasks

- [ ] Semua produsen hanya `ingest(candidate)`:
      bridge, Spotify/Music notification, AppleScript poller, JS probe,
      CoreAudio presence.
- [ ] Satu `reconcile()` memilih lalu memanggil `updateTrack`/`applyPresentation`.
- [ ] Paused dari app non-aktif tidak pernah sampai ke UI.
- [ ] Pertahankan guard command yang sudah ada.

### Acceptance

- Pause Spotify saat YouTube playing tidak mengubah UI.
- Tidak ada jalur yang memanggil `updateTrack` langsung dari produsen.

---

## Phase 4 — Polling

### Tasks

- [ ] Hapus early-return `bridge.isAvailable && hasActiveTrack`.
- [ ] Polling browser tetap jalan saat bridge paused/kosong.
- [ ] Polling lokal hanya untuk app yang punya adapter AppleScript.
- [ ] Turunkan frekuensi saat ada kandidat playing agar tidak boros.

### Acceptance

- YouTube yang mulai playing terdeteksi walau Spotify paused.
- Bridge yang paused tidak menghentikan polling.

---

## Phase 5 — UI kartu generik

### Tasks

- [ ] `hasMediaSession` dan migrasi call site.
- [ ] Card `audioOnly` di pill, drawer, menu bar.
- [ ] Capability-based controls + tombol "Buka App".
- [ ] Sembunyikan progress/lyrics untuk `audioOnly`.
- [ ] Localization + aksesibilitas.
- [ ] Setting "Sertakan app audio lain".

### Acceptance

- Zoom/Teams tampil sebagai kartu audio-only yang jujur.
- Tidak ada tombol transport yang tidak berfungsi.
- Layout notch/drawer tidak bergeser.

---

## Phase 6 — Artwork

### Tasks

- [ ] Generation guard untuk request async.
- [ ] Clear/placeholder saat identitas berubah.
- [ ] Cover browser dari `activeWebTarget`/YouTube saat bridge tidak membawa
      artwork.
- [ ] Tambah `displayID` ke `artworkKey` adapter.

### Acceptance

- Ganti track/sumber selalu mengganti cover; cover lama tidak menimpa.
- Sumber tanpa cover menampilkan placeholder, bukan cover sebelumnya.

---

## Phase 7 — Command routing

### Tasks

- [ ] Routing berbasis capability.
- [ ] Command ke kandidat aktif, bukan system player.
- [ ] Fallback AppleScript/JS dipertahankan.
- [ ] Sembunyikan kontrol yang tidak didukung.

### Acceptance

- Saat UI menampilkan YouTube, pause mem-pause YouTube.
- Saat UI menampilkan Zoom, tidak ada tombol palsu.

---

## Phase 8 — Adapter per-player (opsional)

### Tasks

- [ ] Enumerasi client + baca info/state per player di adapter.
- [ ] Kirim command ke player path pilihan.
- [ ] Hapus ketergantungan pada `GetNowPlayingInfo` global.

### Acceptance

- Deteksi multi-app akurat tanpa bergantung pada player yang diingat macOS.

---

## File yang akan tersentuh

Baru:

- `Harmonotch/Features/Media/MediaCandidate.swift`
- `Harmonotch/Features/Media/MediaSelector.swift`
- `Harmonotch/Features/Media/MediaPresentation.swift`
- `Harmonotch/Features/Media/MediaAppInfo.swift`
- `Harmonotch/Features/Media/AudioProcessPresence.swift`
- `Harmonotch/Features/Media/AudioProcessResolver.swift`
- `Harmonotch/NotchUI/MediaAudioOnlyCard.swift` (atau view di dalam
  `MediaDrawerView`)

Diubah:

- `Harmonotch/Features/Media/MediaManager.swift`
- `Harmonotch/Features/Media/NowPlaying/NowPlayingAdapter.m`
- `Harmonotch/Features/Media/NowPlaying/NowPlayingBridge.swift`
- `Harmonotch/Features/Media/NowPlaying/NowPlayingState.swift`
- `Harmonotch/Features/Media/WebMediaSnapshot.swift` (identity/kandidat)
- `Harmonotch/Features/Media/MediaDrawerView.swift`
- `Harmonotch/NotchUI/NotchPillView.swift`
- `Harmonotch/NotchUI/NotchContainerView.swift`
- `Harmonotch/NotchUI/NotchViewModel.swift`
- `Harmonotch/NotchUI/NotchTab.swift`
- `Harmonotch/NotchUI/NotchWindowController.swift`
- `Harmonotch/Features/MenuBar/Sections/DashboardNowSection.swift`
- `Harmonotch/App/AppDelegate.swift`
- `Harmonotch/Features/Localization/L10n.swift`
- `Harmonotch/App/UserDefaultsKeys.swift` (setting include other audio apps)
- `Tests/main.swift`
- `Tests/run-tests.sh`

---

## Matriks tes

| Skenario | Harapan |
|---|---|
| App A playing, app B paused | A |
| App B pause saat A playing | Tetap A |
| Dua app playing | Music app menang; jika sama-sama non-music, yang lebih dulu playing |
| Semua paused | Sumber terakhir tetap tampil |
| App audio tanpa metadata (Zoom) | Kartu audio-only, nama app, tanpa progress/lyrics, ada "Buka App" |
| Notifikasi sistem 0.5 detik | Tidak muncul kartu |
| Safari memutar YouTube | Helper WebKit merge ke Safari, metadata tampil |
| Spotify paused + Zoom audio | Zoom |
| Dua app audio-only | Yang mulai lebih dulu; seri → frontmost |
| App audio berhenti | Kartu hilang setelah 3 detik |
| Toggle "app audio lain" mati | Hanya app ber-metadata tampil |
| Ganti track di app mana pun | Judul, durasi, cover berganti |
| Cover lama selesai belakangan | Tidak menimpa cover baru |
| Pause saat YouTube tampil | YouTube yang pause |

---

## Risiko

1. Resolusi parent process untuk helper browser berbeda per app. Kalau gagal,
   app induk tidak terdeteksi dan hanya metadata MediaRemote yang tampil.
   Mitigasi: tes unit untuk rantai parent + fallback path executable.
2. `IsRunningOutput` bisa menangkap system sound/daemon. Mitigasi: debounce 1.5
   detik, exclusion PID sendiri/daemon, dan resolusi app bundle.
3. App panggilan (Zoom/Teams) akan tampil sebagai audio-only. Mitigasi: setting
   include/exclude.
4. Command routing baru bisa mengirim ke app yang salah kalau `activeWebTarget`
   menunjuk tab lama. Mitigasi: validasi URL/tab sebelum mengirim.
5. Refactor `MediaSource` menyentuh banyak call site. Mitigasi: shim
   `mediaSource` sampai semua pindah.
6. CoreAudio process API berbeda antar versi macOS. Mitigasi: cek ketersediaan
   saat runtime dan fallback ke MediaRemote-only.

## Urutan implementasi

1. Phase 0 + Phase 1 + Phase 2 (model dan tes, tanpa UI).
2. Phase 3 + Phase 4 (arbiter dan polling).
3. Phase 5 (UI generik).
4. Phase 6 + Phase 7 (artwork dan command routing).
5. Phase 8 hanya jika Phase 1-7 masih menyisakan kasus salah sumber.

## Keputusan yang masih terbuka

- Apakah app komunikasi (Zoom/Teams) ditampilkan default atau opt-in.
- Apakah user boleh memilih sumber manual (seperti Vorssaint), atau selalu
  otomatis.
- Nama setting untuk "Sertakan app audio lain".
