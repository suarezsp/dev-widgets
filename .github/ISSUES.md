# Issues for v1.0

What is missing before the first release (v1.0), written so each entry
can be pasted as a GitHub issue. The evidence comes from the code, the
project report (`docs/report/report.tex`: "Lo que no se ha podido
verificar", "Limitaciones conocidas", "Estado general y lo que falta")
and the checks run on a real Mac (macOS 27.2.1, M1 Pro) on
2026-11-10.

**Verified so far:** `swift build` and `swift test` (236 tests on
macOS, 234 on Linux); `xcodebuild` of the app, widget extension and
App Intents with no errors or warnings; signing with team
`TZX43BGUAU` and the team-prefixed App Group; the app saving
snapshots every 60 s with no sandbox denials; real CPU, memory,
disk, battery and thermal readings at idle; the Linux `.deb` on a
virtual XFCE desktop.

**Labels used:** `release`, `macos`, `linux`, `widgets`, `app`,
`intents`, `integration`, `testing`, `ci`, `docs`, `packaging`,
`design`, `a11y`, `l10n`, `bug`.

**Summary:** 14 blockers, 10 should have, 8 post-1.0.

---

## Milestone: Blockers for v1.0

### 1. Repository URL points to `suarezsp/devwidgets`, the repo is `suarezsp/dev-widgets`

- **Labels:** `docs`, `packaging`, `bug`
- **Priority:** blocker
- **Problem:** The repository was published as
  `github.com/suarezsp/dev-widgets`, but the clone command in the
  README, the `.deb` homepage, the AppStream homepage and the commit
  plan use `github.com/suarezsp/devwidgets`, which does not exist.
- **Acceptance criteria:**
  - [ ] One name is chosen (rename the repo to `devwidgets` or update every URL to `dev-widgets`).
  - [ ] `grep -rn "suarezsp/" .` shows only the chosen URL.
  - [ ] `git clone` from the README works.
- **Files:** `README.md`, `packaging/linux/control.in`,
  `packaging/linux/com.morsetechnologies.DevWidgets.metainfo.xml`,
  `.github/COMMITS.md`

### 2. Widget extension is built without the hardened runtime

- **Labels:** `macos`, `release`, `bug`
- **Priority:** blocker
- **Problem:** Notarization requires the hardened runtime on every
  executable. `codesign -dv` on the Xcode build shows
  `flags=0x10000(runtime)` for `DevWidgets.app` but `flags=0x0(none)`
  for `DevWidgetsWidgets.appex`: `project.yml` sets
  `ENABLE_HARDENED_RUNTIME` only on the app target.
- **Acceptance criteria:**
  - [ ] `ENABLE_HARDENED_RUNTIME: YES` on `DevWidgetsWidgets`.
  - [ ] `codesign -dv` shows `runtime` for the app and the extension.
  - [ ] The widgets still load data (see #4).
- **Files:** `macOS/project.yml`

### 3. Developer ID signing, notarization, DMG and a release workflow

- **Labels:** `release`, `macos`, `ci`, `packaging`
- **Priority:** blocker
- **Problem:** The README documents Developer ID signing,
  notarization and a DMG, but none has been produced, and there is no
  release workflow: `.github/workflows/ci.yml` only builds with
  `CODE_SIGNING_ALLOWED=NO`. Needs the paid Apple Developer Program.
- **Acceptance criteria:**
  - [ ] A Developer ID Application certificate exists for team `TZX43BGUAU`.
  - [ ] An archive of `DevWidgetsApp` signed with Developer ID passes `xcrun notarytool submit --wait` and is stapled.
  - [ ] A DMG with the app and an `/Applications` link is signed, notarized and stapled; `spctl -a -t open --context context:primary-signature -v DevWidgets.dmg` accepts it.
  - [ ] A workflow on tag `v*` builds, signs, notarizes and attaches the DMG and the `.deb` to a GitHub release; the certificate and notary credentials live in repository secrets, never in the repo.
- **Files:** `macOS/project.yml`, `.github/workflows/` (new
  `release.yml`), `README.md`

### 4. Confirm end to end that every widget shows live data on the desktop

- **Labels:** `widgets`, `macos`, `testing`
- **Priority:** blocker
- **Problem:** On the real Mac the app saves snapshots
  (`Saved snapshot for the widgets` every 60 s), but no one has yet
  seen a widget placed on the desktop showing that data. The extension
  reads the App Group name from its own Info.plist key
  `DevWidgetsAppGroup`; that path has only been checked by
  inspecting the built bundle.
- **Acceptance criteria:**
  - [ ] Metric (small, medium), dashboard (large, extra large), developer context (medium, large) and servers (medium, large) are added from the gallery and show data within one refresh.
  - [ ] Values match the menu bar panel within one publish interval.
  - [ ] Quitting the app leaves the last data shown, and the empty state appears only before the first snapshot.
- **Files:** `macOS/Shared/AppGroup.swift`,
  `macOS/Widgets/SnapshotTimelineProvider.swift`,
  `macOS/App/WidgetPublisher.swift`

### 5. Native Liquid Glass in every rendering mode, on the real desktop

- **Labels:** `design`, `widgets`, `macos`, `testing`
- **Priority:** blocker
- **Problem:** The widgets now use `containerBackground(.fill.tertiary,
  for: .widget)` and read `widgetRenderingMode`, but every image in the
  repo is an `ImageRenderer` render on a neutral platter. The
  appearance in the clear, tinted and full-color presentations, light
  and dark, has never been seen on a desktop. Whether
  `.fill.tertiary` in full color looks like Apple's widgets is listed
  as unverified in the report.
- **Acceptance criteria:**
  - [ ] Every widget and size is checked in the clear, tinted and full-color presentations, light and dark, next to Apple's widgets.
  - [ ] No custom background shows in clear or tinted; warnings stay readable when the system removes color.
  - [ ] Desktop screenshots replace the renders in the README.
- **Files:** `macOS/Widgets/Views/*.swift`,
  `macOS/Shared/HistoryChart.swift`, `macOS/Shared/MetricRow.swift`,
  `macOS/Shared/LoadLevelStyle.swift`, `README.md`

### 6. First run on a clean Mac from the DMG

- **Labels:** `release`, `macos`, `testing`
- **Priority:** blocker
- **Problem:** All runs so far were Xcode builds on the developer's
  Mac. That Mac still keeps the old
  `group.com.morsetechnologies.devwidgets` container from an ad-hoc
  build, which macOS denied to the signed app. The team-prefixed group
  avoids it, but a first install for a new user has not been tried.
- **Acceptance criteria:**
  - [ ] On a Mac (or new user account) without Xcode, installing from the notarized DMG and opening the app shows no Gatekeeper warning and no "would like to access data from other apps" prompt.
  - [ ] The App Group container is created and the widgets get data (#4).
  - [ ] The notification permission prompt appears once and alerts work after allowing it.
  - [ ] Nothing asks the user to move or delete folders.
- **Files:** `macOS/App/*.swift`, `macOS/project.yml`, `README.md`

### 7. Start at login

- **Labels:** `app`, `macos`
- **Priority:** blocker
- **Problem:** The widgets only get data while the menu bar app runs,
  and there is no login item in the code (no `SMAppService`). After a
  restart the widgets keep old data until the user opens the app by
  hand.
- **Acceptance criteria:**
  - [ ] A "Start at login" setting uses `SMAppService.mainApp`, on by default after the first launch or offered on first run.
  - [ ] After a restart the app is in the menu bar and the widgets update without user action.
- **Files:** `macOS/App/` (Settings and app entry point)

### 8. App Intents and the two-tap confirmation on a real widget

- **Labels:** `intents`, `widgets`, `testing`
- **Priority:** blocker
- **Problem:** Stop or restart a container, quit a process (tap twice
  to confirm) and open the project are compiled but have never been
  tapped on a placed widget. The report lists as unverified whether
  WidgetKit reloads in time to show "Confirm", `notify_post` from the
  sandboxed extension, and opening the project with `NSWorkspace`.
- **Acceptance criteria:**
  - [ ] First tap shows "Confirm", second tap performs the action, and the confirmation expires if not tapped.
  - [ ] Quit process, stop and restart container, and open project each work from the widget, and a failure (e.g. permissions) is shown.
  - [ ] The metric picker (`SelectMetricIntent`) changes the metric of a placed widget.
- **Files:** `macOS/Widgets/WidgetActionIntents.swift`,
  `macOS/Widgets/ArmedActionTimeline.swift`,
  `macOS/Widgets/SelectMetricIntent.swift`,
  `macOS/App/ActionHandler.swift`, `macOS/App/ProjectOpener.swift`

### 9. Docker against a real engine

- **Labels:** `integration`, `testing`
- **Priority:** blocker
- **Problem:** Docker parsing is tested only with fixtures written
  from the `docker ps/stats --format` documentation. `docker stop` and
  `docker restart` have never run against a real engine; Docker
  Desktop, Colima and OrbStack are untested.
- **Acceptance criteria:**
  - [ ] Containers, CPU and memory match `docker stats` with Docker Desktop and with at least one of Colima or OrbStack.
  - [ ] Stop and restart work from the panel and from the widget.
  - [ ] "Not running" is shown when the engine is stopped, and the 5 s timeout is not hit on a normal machine.
  - [ ] A fixture recorded from the real engine is added.
- **Files:** `Sources/DevWidgetsCore/Context/DockerReader.swift`,
  `Sources/DevWidgetsCore/Context/DockerParsers.swift`,
  `Tests/Fixtures/docker/`, `Tests/DevWidgetsCoreTests/DockerTests.swift`

### 10. GitHub with a real account (token and `gh`)

- **Labels:** `integration`, `testing`
- **Priority:** blocker
- **Problem:** GitHub has been tested with recorded or hand-written
  responses only. Unverified: the token stored in the Keychain,
  `gh api -i` and its 304 with a session (format taken from `gh`'s
  source), the review queue with `@me`, private repositories, and
  opening the run when a failed-CI notification is clicked.
- **Acceptance criteria:**
  - [ ] With a token in Settings and with `gh auth login`, the branch's pull request, review state and CI show correctly for a private repo.
  - [ ] The review queue with `review-requested:@me` lists real requests.
  - [ ] A repeated request returns 304 and is served from the ETag cache.
  - [ ] A failed run sends one notification that opens the run.
- **Files:** `Sources/DevWidgetsCore/GitHub/`, `macOS/App/` (Settings,
  Keychain, `UserNotifier.swift`), `Tests/Fixtures/github/`

### 11. SSH servers from the macOS app

- **Labels:** `integration`, `macos`, `testing`
- **Priority:** blocker
- **Problem:** SSH was tested only against a local `sshd` on Linux.
  Unverified: that `ssh` launched from a menu bar app uses the macOS
  agent and Keychain keys, real servers on another network
  (`ProxyJump`, latency), and the servers widget on the desktop.
- **Acceptance criteria:**
  - [ ] A host from `~/.ssh/config` using the macOS agent shows CPU, memory and disk in the panel and the widget.
  - [ ] A `ProxyJump` host works; a refused key and an unreachable host show their reasons.
  - [ ] The server-down alert fires once and clears.
- **Files:** `Sources/DevWidgetsCore/Remote/`,
  `macOS/App/ServersModel.swift`, `macOS/Widgets/ServersWidget.swift`

### 12. macOS system integrations not yet run

- **Labels:** `macos`, `app`, `testing`
- **Priority:** blocker
- **Problem:** Listed as unverified in the report: `lsof` on macOS
  (format taken from the docs, never executed; speed with many
  processes), the Keychain, `UNUserNotificationCenter`, the folder
  picker and `UserDefaults`, `confirmationDialog` inside
  `MenuBarExtra`, `openSettings`, and launching programs under the
  hardened runtime.
- **Acceptance criteria:**
  - [ ] Listening ports on macOS match `lsof -iTCP -sTCP:LISTEN` and refresh in under 1 s on a busy Mac.
  - [ ] Choosing a project folder persists across restarts and Git status follows it.
  - [ ] Settings opens from the panel; confirmation dialogs work in the menu bar panel.
  - [ ] `git`, `docker`, `gh`, `ssh` and `lsof` launch from the signed, hardened app.
- **Files:** `Sources/DevWidgetsCore/Context/`, `macOS/App/`

### 13. CI green on GitHub

- **Labels:** `ci`
- **Priority:** blocker
- **Problem:** CI has never run. The pushed `.gitignore` ends with
  `.github/`, so `.github/workflows/ci.yml` (and this file) are not in
  the repository and GitHub runs no workflow. The workflow uses the
  `swift:6.2` container on Linux (local tests ran with Swift 6.4 on
  Linux and 6.3 on macOS) and the `macos-26` runner with
  `swiftlint lint --strict`, `swift test` and an unsigned
  `xcodebuild`.
- **Acceptance criteria:**
  - [ ] `.gitignore` no longer ignores `.github/` (ignore only real secrets, e.g. `.env`, `*.p12`, `*.p8`); `.github/workflows/ci.yml` is committed.
  - [ ] Both jobs pass on `main`.
  - [ ] Failures found on the first run are fixed in code, not by relaxing the checks.
  - [ ] A status badge in the README links to the workflow.
- **Files:** `.gitignore`, `.github/workflows/ci.yml`, `README.md`

### 14. One version number and a release changelog

- **Labels:** `release`, `docs`
- **Priority:** blocker
- **Problem:** The macOS app is `MARKETING_VERSION: "0.1.0"`
  (`macOS/project.yml`), the `.deb` defaults to `VERSION=0.6.0`
  (`tools/package_deb.sh`), and `CHANGELOG.md` is organized by
  development phase, not by version.
- **Acceptance criteria:**
  - [ ] Both platforms take the version from one place and ship as `1.0.0`.
  - [ ] `CHANGELOG.md` has a `1.0.0` section in a standard format (e.g. Keep a Changelog), with the phases summarized below it.
  - [ ] The git tag `v1.0.0` matches.
- **Files:** `macOS/project.yml`, `tools/package_deb.sh`,
  `packaging/linux/changelog.Debian`, `CHANGELOG.md`

---

## Milestone: Should have

### 15. Widget refresh budget in real use

- **Labels:** `widgets`, `testing`
- **Priority:** high
- **Problem:** The app publishes at most once per 60 s and asks
  WidgetKit to reload; the context widget reloads on change at most
  every 30 s. WidgetKit can delay or drop reloads, and container CPU
  in the widget can be stale because it does not trigger reloads. The
  real cadence over hours has not been measured.
- **Acceptance criteria:**
  - [ ] Over at least 4 hours of normal use, the time between snapshot and widget update is logged and documented.
  - [ ] Intervals are adjusted if reloads are being dropped, and the README states what users should expect.
- **Files:** `macOS/App/WidgetPublisher.swift`,
  `macOS/App/ContextPublisher.swift`, `macOS/App/ServersModel.swift`

### 16. Privacy and permissions documentation

- **Labels:** `docs`
- **Priority:** high
- **Problem:** The app is not sandboxed (it lists and quits
  processes), runs `git`, `docker`, `gh`, `ssh` and `lsof`, calls the
  GitHub API, stores a token in the Keychain and sends notifications.
  None of this is gathered in one place for users.
- **Acceptance criteria:**
  - [ ] A `PRIVACY.md` (linked from the README) lists what is read, what commands run, what goes over the network (GitHub only), where data is stored (App Group, Keychain, `UserDefaults`) and that nothing is sent elsewhere.
  - [ ] It explains each permission prompt the user may see.
- **Files:** new `PRIVACY.md`, `README.md`

### 17. App icon

- **Labels:** `app`, `macos`, `design`
- **Priority:** high
- **Problem:** The built app has no `Contents/Resources` and the
  `macOS/` folder has no asset catalog or `.icns`, so the app shows a
  generic icon in Finder, the DMG and notifications. Linux already
  has an icon in `packaging/linux/icons`.
- **Acceptance criteria:**
  - [ ] An `AppIcon` asset catalog for the app (and the extension if needed), referenced in `project.yml`.
  - [ ] The icon shows in Finder, the DMG, notifications and Settings.
- **Files:** `macOS/project.yml`, new `macOS/App/Assets.xcassets`

### 18. Accessibility of widgets and panel

- **Labels:** `a11y`, `widgets`, `app`
- **Priority:** high
- **Problem:** There are 2 `accessibilityLabel` uses in `macOS/`.
  Rings, bars and charts have no spoken values, and warnings are
  conveyed by color in full color.
- **Acceptance criteria:**
  - [ ] VoiceOver reads each metric as name, value and level, and each chart as a summary.
  - [ ] Action buttons have labels; warnings are not conveyed by color alone.
  - [ ] Checked with VoiceOver and the Accessibility Inspector.
- **Files:** `macOS/Shared/*.swift`, `macOS/Widgets/Views/*.swift`

### 19. Linux on real desktops: GNOME, KDE, Wayland

- **Labels:** `linux`, `testing`
- **Priority:** high
- **Problem:** Only XFCE on Xvfb (X11, no GPU) was tested.
  Unverified: GNOME (tray needs the AppIndicator extension), KDE
  Plasma, Cinnamon, Wayland, notifications on GNOME, HiDPI and GPU
  performance.
- **Acceptance criteria:**
  - [ ] The `.deb` installs and runs on Ubuntu 24.04 GNOME (Wayland) and a KDE Plasma distribution.
  - [ ] Tray icon, notifications and confirmations work, or a clear fallback is documented (GNOME without AppIndicator).
- **Files:** `Sources/devwidgets-linux/`,
  `Sources/DevWidgetsLinuxShell/`, `packaging/linux/`

### 20. Build the GTK app in CI

- **Labels:** `ci`, `linux`
- **Priority:** medium
- **Problem:** `Package.swift` builds the GTK app only where the
  libadwaita headers exist; the CI Linux job does not install them, so
  `devwidgets-linux` and the `.deb` are never built in CI.
- **Acceptance criteria:**
  - [ ] A Linux job installs `libgtk-4-dev` and `libadwaita-1-dev`, builds `devwidgets-linux` and runs `tools/package_deb.sh`.
  - [ ] The `.deb` is uploaded as an artifact.
- **Files:** `.github/workflows/ci.yml`, `tools/package_deb.sh`

### 21. macOS readings under load

- **Labels:** `macos`, `testing`
- **Priority:** medium
- **Problem:** Real values were checked at idle only. Unverified: GPU
  `Device Utilization %` under load, how many processes are visible
  without privileges, and thermal states when hot. Disk activity sums
  every `IOBlockStorageDriver`, including external disks and mounted
  images.
- **Acceptance criteria:**
  - [ ] GPU, CPU and thermal state compared with Activity Monitor and `powermetrics` under load.
  - [ ] Behaviour with an external disk documented or fixed.
- **Files:** `Sources/DevWidgetsDarwin/`

### 22. Separate report-only artifacts from the product

- **Labels:** `docs`
- **Priority:** medium
- **Problem:** The repo carries the Spanish development report
  (`docs/report/report.tex` and about 23 MB of images), HTML/CSS
  mockups whose presentation logic is duplicated in JavaScript
  (`mockups/`, `tools/render_mockups.py`), and render/compositing
  tools used only for the report.
- **Acceptance criteria:**
  - [ ] Decide what stays: keep `macOS/Render` and the compose tools only if they produce README images.
  - [ ] Move the report and mockups to a `docs` branch, a release asset or a separate repo, or document clearly why they stay.
  - [ ] No file in the default branch is only needed by the report.
- **Files:** `docs/report/`, `mockups/`, `tools/render_mockups.py`,
  `tools/compose_comparison.py`

### 23. Localization-ready strings

- **Labels:** `l10n`, `app`, `widgets`
- **Priority:** medium
- **Problem:** All user-facing strings are English literals; there is
  no String Catalog.
- **Acceptance criteria:**
  - [ ] Strings live in a String Catalog (`Localizable.xcstrings`) for the app and the extension.
  - [ ] Formatting of numbers and units follows the user's locale.
- **Files:** `macOS/App/`, `macOS/Widgets/`, `macOS/Shared/`

### 24. Flatpak build

- **Labels:** `linux`, `packaging`
- **Priority:** medium
- **Problem:** `packaging/flatpak/com.morsetechnologies.DevWidgets.yml`
  has never been built; notifications through the portal are
  untested, and the sandbox limits access to processes and tools.
- **Acceptance criteria:**
  - [ ] `flatpak-builder` builds and runs the app.
  - [ ] Which features work inside the sandbox (processes, Docker, `ssh`, `git`) is documented, using `flatpak-spawn --host` where needed.
- **Files:** `packaging/flatpak/`

---

## Milestone: Post-1.0

### 25. Automatic updates

- **Labels:** `release`, `macos`
- **Priority:** medium
- **Problem:** There is no update mechanism; users must download each
  DMG by hand.
- **Acceptance criteria:**
  - [ ] Signed updates (e.g. Sparkle with an appcast from GitHub releases).
- **Files:** `macOS/App/`, `.github/workflows/`

### 26. Spanish localization

- **Labels:** `l10n`
- **Priority:** medium
- **Problem:** After #23, the app can ship a Spanish translation.
- **Acceptance criteria:**
  - [ ] Spanish strings for the app, widgets and Linux app.
- **Files:** String Catalog, `Sources/devwidgets-linux/`

### 27. NVIDIA GPU on Linux

- **Labels:** `linux`
- **Priority:** medium
- **Problem:** Linux GPU reads only AMD (`gpu_busy_percent`); NVIDIA
  needs NVML.
- **Acceptance criteria:**
  - [ ] GPU load on NVIDIA, tested on real hardware.
- **Files:** `Sources/DevWidgetsCore/Linux/`

### 28. Linux tray menu, RPM and arm64

- **Labels:** `linux`, `packaging`
- **Priority:** medium
- **Problem:** The tray icon has no context menu (a click toggles the
  panel); packages are `.deb` for `amd64` only.
- **Acceptance criteria:**
  - [ ] Tray menu with show/hide, settings and quit.
  - [ ] RPM and `arm64` builds.
- **Files:** `Sources/devwidgets-linux/`, `tools/package_deb.sh`,
  `packaging/linux/`

### 29. More than one project and GitHub Enterprise

- **Labels:** `integration`
- **Priority:** medium
- **Problem:** Git follows a single project; GitHub supports only
  `github.com`; the review search has no ETag and lists at most 10
  pull requests.
- **Acceptance criteria:**
  - [ ] Several projects selectable in Settings and in the context widget.
  - [ ] A configurable GitHub Enterprise host.
- **Files:** `Sources/DevWidgetsCore/Context/`,
  `Sources/DevWidgetsCore/GitHub/`, `macOS/App/`

### 30. Richer remote servers

- **Labels:** `integration`
- **Priority:** medium
- **Problem:** Servers are Linux only, with one disk each and no
  remote processes or containers. Suggestions ignore `Match` blocks,
  and a host that asks for a password or 2FA shows as a refused key.
- **Acceptance criteria:**
  - [ ] Password/2FA hosts get their own message.
  - [ ] Several disks per server; optional remote containers.
- **Files:** `Sources/DevWidgetsCore/Remote/`

### 31. Temperature in degrees on macOS

- **Labels:** `macos`
- **Priority:** medium
- **Problem:** macOS shows only the thermal state, because there is
  no public API for temperatures; reading the SMC would be fragile and
  private.
- **Acceptance criteria:**
  - [ ] Revisit if Apple adds a public API; until then the README says so.
- **Files:** `Sources/DevWidgetsDarwin/`

### 32. Quit processes more gracefully

- **Labels:** `app`
- **Priority:** medium
- **Problem:** Quitting sends only SIGTERM and works only for the
  user's processes; a permission failure shows as a refusal.
- **Acceptance criteria:**
  - [ ] Apps quit through `NSRunningApplication.terminate()` first; a clear message when a process is not the user's.
- **Files:** `Sources/DevWidgetsCore/Actions/`, `macOS/App/ActionHandler.swift`
