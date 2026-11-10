# Test fixtures

Which files are recorded from a real machine and which are written
by hand, because the build box has no such device or program.

| Path | Origin |
| --- | --- |
| `proc/stat`, `proc/meminfo`, `proc/net/dev`, `proc/diskstats`, `proc/pressure/memory` | Recorded on the Linux build box, trimmed; `docker0` line in `net/dev` added by hand. |
| `proc/net/tcp`, `proc/net/tcp6` | Header recorded; rows written by hand in the kernel format (real rows are the box's own services). |
| `proc/77`, `proc/4242` (`stat`, `comm`, `fd/*` links) | Hand-written in the kernel format. |
| `sys/class/...` | Hand-written: the box has no GPU, sensor or battery. |
| `git/*.txt` | Recorded: real `git status --porcelain=v2 --branch` output from scratch repositories (rename, conflict, ahead/behind, detached HEAD). |
| `docker/*.jsonl` | **Hand-written** in the `docker ps/stats --format '{{json .}}'` format: the box has no Docker. |
| `lsof/listen.txt` | **Hand-written** in the `lsof -F pcn` format: the box has no `lsof`; it is the macOS source. |
| `github/pulls-branch.json`, `pulls-none.json`, `runs-branch.json`, `runs-main.json`, `reviews-approved.json`, `reviews-none.json` | **Recorded** on 2026-11-10 from the public GitHub REST API (anonymous) for `swiftlang/swift-format`, trimmed to the fields DevWidgets reads. |
| `github/reviews-mixed.json`, `github/runs-in-progress.json` | **Hand-written** in the REST format: a dismissal and a change request, a re-run and a run in progress, which the public repository did not show that day. |
| `github/gh-not-logged-in.txt` | **Recorded**: real stderr of `gh api` without `gh auth login`. |
| `github/gh-http-404.txt` | **Hand-written** in `gh`'s error format: no signed-in `gh` on the box. |
| `github/search-review-requested.json` | **Recorded** on 2026-11-10 from the public search API (anonymous) with an explicit reviewer (`review-requested:ahoppen`) instead of `@me`, trimmed to 5 items (one is a draft). |
| `github/search-me-anonymous-422.json` | **Recorded**: the 422 the search API gives `@me` without a token. |
| `github/search-none.json` | **Hand-written**: an empty search result. |
| `github/gh-include-200.txt` | **Hand-written** in the `gh api -i` format (status line, real headers, real `pulls-branch.json` body): no signed-in `gh` on the box. The format was taken from the gh source. |
| `github/gh-http-304.txt` | **Hand-written**: the `HTTP 304` stderr `gh api` prints for a not-modified page (per the gh source). |
| `ssh/probe-linux-1.txt`, `ssh/probe-linux-2.txt` | **Recorded**: output of `RemoteProbe.SCRIPT` over real `ssh` to a local `sshd` on the build box (`tools/ssh_test_server.sh`), 5 s apart. |
| `ssh/probe-darwin.txt` | **Hand-written**: what the script prints on a host without `/proc`. |
| `ssh/error-host-key.txt`, `ssh/error-permission-denied.txt`, `ssh/error-connection-refused.txt` | **Recorded**: real `ssh` stderr against the local `sshd` (wrong known_hosts, unknown key, closed port). |
| `ssh/config-sample.txt` | **Hand-written** `~/.ssh/config` with host patterns and an `Include`. |
