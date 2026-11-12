# Changelog

All notable changes are listed here, in the format of
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions
follow [Semantic Versioning](https://semver.org/); the version lives
in `macOS/project.yml` (`MARKETING_VERSION`).

## [Unreleased]

### Added

- macOS: the menu bar app starts at login after the first launch;
  Settings › General turns it off.
- Linux: the tray icon has a right-click menu (dbusmenu) to show or
  hide the dashboard, open Preferences and quit.
- Linux: `tools/package_rpm.sh` builds an `.rpm`, and CI builds
  both packages for `x86_64` and `arm64`.
- macOS: user-facing texts live in a String Catalog
  (`macOS/Shared/Localizable.xcstrings`) shared by the app and the
  widgets, ready for translation; `tools/sync_strings.sh` adds new
  ones after a build.
- macOS: Spanish translation of the app, the widgets and their
  intents, used when Spanish is the preferred language.
- Linux: GPU load on NVIDIA cards, read through `nvidia-smi` when
  the driver has no busy file in `/sys`.
- GitHub Enterprise Server: a host in Settings › GitHub (macOS) or
  `GH_HOST` (Linux) points the REST API and `gh` at it.
- Linux: the Flatpak manifest builds and runs (no network during
  the build) and passes `ssh-agent`; `packaging/flatpak/README.md`
  lists what works inside the sandbox.
- Flatpak: Git, Docker and `gh` run on the host through
  `flatpak-spawn --host`, so the project status works there.
- Linux: Spanish, read from the same String Catalog as macOS
  (installed in `share/devwidgets`) when the locale asks for it.
- Decimals use the separator of the interface language ("2,3 GB"
  in Spanish).

### Changed

- One version for both platforms: macOS moves from 0.1.0 to 0.6.0,
  and `tools/package_deb.sh` reads it from `macOS/project.yml`.
- The widget extension is built with the hardened runtime, as
  notarization requires.
- `.github/` (CI workflow and issue list) is now tracked.
- macOS: quitting an app sends the Dock's Quit before any signal,
  and a process owned by another user says so instead of looking
  like a refusal.

### Removed

- The development report (`docs/report/`) and the HTML/CSS mockups
  with their render script left the default branch; they live on
  the `report` branch. README images moved to `docs/images/`.

### Fixed

- Repository URLs point at `github.com/suarezsp/dev-widgets`.
- The app and widget bundles report the project version; XcodeGen
  wrote "1.0" in both Info.plist files.
- "1 request awaits you" in the review line (it said "await").

## [0.6.0] - 2026-11-10

The macOS widgets and menu bar app, and the Linux GTK 4 app and
`.deb`, built in six development phases. The `.deb` shipped as
0.6.0; the macOS app was numbered 0.1.0 until this version was
made the shared one.

### Phase 6 — 2026-11-10

- Linux app (`devwidgets-linux`, installed as `devwidgets`): GTK 4
  and libadwaita through Swift's C interop (`CGtk` system library,
  thin hand-written layer), dashboard window with four small, one
  medium and three large cards at the macOS sizes, glass look in
  GTK CSS with a dark variant, Cairo rings, bars and history
  charts, process quit and container stop/restart with an
  `AdwAlertDialog` confirmation and toasts, preferences (alert
  limits and events, servers with disk and `~/.ssh/config`
  suggestions, project folder, GitHub source), StatusNotifierItem
  tray icon over GDBus (hide on close only when a panel shows it),
  GNotification alerts (clicking a CI alert opens the run).
- `DevWidgetsLinuxShell` (portable, tested): settings file,
  `AlertRouter`, tray texts and properties, launch options, GitHub
  source, icon lookup.
- Core: ssh `Include` (globs, `~`, relative paths, loop guard) in
  `SSHConfigReader`; disk path per server (`df -kP <path>`), older
  saved hosts default to `/`; `ServerDownMonitor` (one alert after
  a minute unreachable, auth or host-key problems never alert);
  `DeveloperContextRefresher` shared by macOS and Linux;
  `DockerState.listBusiest`, `ActionOutcome.describeFailure`,
  `AlertMetric.limit_Range`/`limit_Step` moved out of macOS views.
- Packaging: `tools/package_deb.sh` (static Swift runtime, full
  RELRO, dependencies from `dpkg-shlibdeps`, lintian clean except
  the missing homepage), `.desktop`, metainfo, icon, man page;
  experimental Flatpak manifest (not built).
- macOS (not compiled yet): server-down notifications and switch,
  disk field per server, suggestions from `Include` files, context
  model on the shared refresher; presentation API made public for
  Linux.
- Fixes: port owners of daemons that retitle themselves (`sshd:
  …`, `postgres: …`) now show the program name.

### Phase 5 — 2026-11-10

- Core: remote Linux servers over the system `ssh` (`RemoteHost`
  with validated aliases, one-shot `RemoteProbe` script reusing the
  `/proc` parsers, `SSHReader` with `BatchMode`, timeouts and
  `ControlMaster` sharing, `SSHErrorParser`, `RemoteTracker`,
  `SSHConfigParser`); `GitHubClient` actor with an ETag cache
  (`If-None-Match`, 304 for REST and `gh api -i`); review queue
  (`review-requested:@me`, drafts excluded, polled every 5 min
  because search sends no ETag); `CIFailureMonitor` on the generic
  `AlertTracker`; `ContainerController` (stop and restart);
  `BlockingWork`; `ReloadThrottle`. 185 core tests in 37 suites,
  including a live suite against a local `sshd`.
- Presentation: review queue and server texts (13 tests).
- macOS (not compiled yet): servers widget, servers in the panel and
  in Settings, review queue in the panel and large context widget,
  failed-CI notification that opens the run, restart buttons,
  persistent GitHub client.
- `devwidgets-probe servers` and `reviews`;
  `tools/ssh_test_server.sh`.
- Fixes: older saved alert settings decode with defaults, GitHub
  client kept across refreshes, blocking work off the cooperative
  pool, "CI cancelled" instead of "CI passing", thread-safe test
  runner, generic alert tracker and reload throttle, server aliases
  validated on decode, clearer restart confirmation.

### Phase 4 — 2026-11-10

- Core: GitHub (`GitRemoteParser`, pull request of the branch, latest
  workflow runs, review decision, `RESTTransport` and
  `GhCommandTransport`, `GitHubSchedule` with rate-limit back-off),
  threshold alerts (`AlertSettings`, `AlertTracker` with sustain,
  hysteresis and cooldown, `AlertMessage`), widget actions
  (`ActionInbox`, `ConfirmationGate`, `ProcessTerminator`,
  `ContainerStopper`), `ContextChangeTracker`. 146 core tests in 28
  suites; GitHub fixtures recorded from the public API or
  hand-written, labelled in `Tests/Fixtures/README.md`.
- `DevWidgetsPresentation` target: 9 portable files of `macOS/`
  compiled and tested on Linux (5 tests).
- macOS (not compiled yet): App Intents for widget buttons with
  two-tap confirmation, Darwin notification signal, Keychain token
  store, user notifications, Settings window, project opener,
  buttons in the panel, context publisher.
- `devwidgets-probe github <folder> [rest]`.
- Fixes: SIGKILL fallback when a timed-out program ignores SIGTERM,
  per-command timeout, context widget reloads on change, stale
  overlapping refreshes dropped, Darwin process name `nil` when
  unknown, `GitReader` split, generic process and container lists,
  `ViewThatFits` container row.

### Phase 3 — 2026-11-10

- Core: `CommandRunner` / `ProcessCommandRunner` (timeout, output
  through temporary files), Docker through its CLI (`ps`, `stats`),
  listening ports (`/proc/net/tcp{,6}` + `/proc/[pid]/fd` on Linux,
  `lsof -F` on macOS), Git `status --porcelain=v2 --branch`,
  `DeveloperContext`, generic `JSONFileStore`. 102 tests in 18
  suites; fixtures labelled in `Tests/Fixtures/README.md`.
- macOS (not compiled yet): `DeveloperContextModel` refreshing every
  10 s off the main thread, project folder picker, medium and large
  developer-context widget, two-column menu bar panel.
- `devwidgets-probe context <folder>`.
- Fixes: `check_style.py` enum-case parsing, `LinuxExtrasReader`
  split into hardware and process readers with `KernelFiles`,
  `ProcessStatParser` in its own file, explicit
  `MetricPresentation.is_Available`, direct memory presentation,
  sampling started from the app `init`, port owners from `cmdline`.

### Phase 2 — 2026-11-10

- Core: GPU, temperature and battery (`HardwareStatus`), top five
  processes (`ProcessRanking`, matched by pid and name), local IPv4
  (`NetworkInterfaces`), network history, `/sys` and
  `/proc/[pid]/stat` parsers. 74 tests in 13 suites.
- Darwin (not compiled yet): 64-bit network counters through
  `NET_RT_IFLIST2`, disk bytes and GPU utilisation through IOKit,
  battery through IOKit power sources, `ProcessInfo.thermalState`,
  processes through libproc.
- Widgets: large and extra-large dashboard with Swift Charts history
  and process list; GPU, thermal and battery in the configurable
  widget; menu bar panel shows IP, available metrics only and top
  processes.
- Phase 1 fixes: `ByteFormatting` → `MetricFormatting`,
  `LoadThresholds` limits, labelled `capacityFromAvailable`,
  `makeTimedSample`, 3-parameter `MetricPresentation`, `MetricHistory`
  and `SampleInterval` instead of `MetricTrends` and repeated
  `(from, to, elapsed)` parameters, physical interfaces only (no
  double-counted Docker/VPN traffic), host app outside the sandbox.
- Fixed `SysfsParser` dropping inner spaces ("Not charging").
- New mockups (large, extra large, updated menu bar panel), report v2.

### Phase 1 — 2026-11-10

- Repository, phase plan, README, prepared (not yet run) CI.
- Quality gates: swift-format, SwiftLint, `tools/check_style.py`
  with its own self-test; one entry point `tools/lint.sh`.
- `DevWidgetsCore`: CPU (total and per core), RAM, swap, memory
  pressure, disk space and I/O, network throughput, load levels,
  history ring buffer, recorder, JSON snapshot store, Linux `/proc`
  readers. 51 tests.
- `DevWidgetsDarwin`: macOS sampler (not compiled yet).
- macOS menu bar app and configurable small and medium widgets
  (not compiled yet).
- HTML/CSS mockups (light, dark, tinted) and report v1.
