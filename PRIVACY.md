# Privacy and permissions

devwidgets runs on your computer and keeps what it reads on your
computer. It has no account, no analytics, no crash reporting and no
server of its own. The only network traffic it starts is to GitHub
(when you set up GitHub) and to the SSH servers you add.

## What it reads

| What | How | When |
|------|-----|------|
| CPU, memory, disk, network, GPU, battery, thermal state | macOS: Mach, `sysctl`, IOKit, power sources, `libproc`. Linux: `/proc` and `/sys` | every second while the app runs |
| Running processes (name, CPU, memory) | `libproc` on macOS, `/proc` on Linux | every second |
| The project folder you choose | `git status --porcelain=v2 --branch` and `git remote get-url` | every 10 s |
| Docker containers | `docker ps --all` and `docker stats --no-stream` | every 10 s, if Docker is installed |
| Listening ports and their programs | `lsof` on macOS, `/proc/net` on Linux | every 10 s |
| GitHub pull requests, reviews and CI runs of that project | GitHub REST API, or `gh api` | every minute (review queue every 5 min), only after you set up GitHub |
| SSH servers you add | your `ssh`, with your keys and `~/.ssh/config` | every 15 s |

Commands run with your user's rights, never as root. devwidgets
itself opens no file in your project; it only uses what `git status`
reports.

## What goes over the network

- **GitHub**, only after you save a token or sign in to `gh`: the
  repository of the chosen project (from its `origin` remote), its
  open pull request, reviews and workflow runs, and the pull requests
  waiting for your review. Requests go to `https://api.github.com/`
  (or through `gh`). Nothing about your machine is sent.
- **Your SSH servers**: one `ssh` connection per server runs a short
  read-only script that prints CPU, memory, disk, load and uptime.
  `BatchMode` is on, so it never asks for or sends a password.

Nothing else leaves your computer.

## What it stores

| What | Where |
|------|-------|
| Latest snapshot, developer context and server status for the widgets | macOS: the app's App Group container (`~/Library/Group Containers/`); Linux: not stored |
| Pending widget actions (quit, stop, restart) | the same App Group container, deleted once done |
| Settings: alert limits, project folder, editor, servers | macOS: `UserDefaults`; Linux: `~/.config/devwidgets/settings.json` |
| GitHub token | macOS: your login Keychain; never in files or settings |
| SSH connection sharing sockets | `/tmp/devwidgets-ssh-<uid>`, readable only by you; `ssh` closes each one after 2 min idle |

Uninstalling the app and deleting its App Group container (or
`~/.config/devwidgets` on Linux) removes everything.

## What it changes

Only what you ask for, from a widget, the panel or a notification:

- **Quit a process**: asks it to quit, never with SIGKILL. On macOS
  an app gets the same Quit as from the Dock, so it can ask to save;
  other processes get SIGTERM. Only your own processes can be quit.
- **Stop or restart a container**: `docker stop` or
  `docker restart`.
- **Open the project**: opens the folder in your editor.

Widget buttons that quit, stop or restart need a second tap to
confirm.

## Permission prompts you may see (macOS)

| Prompt | Why | If you say no |
|--------|-----|---------------|
| Notifications | threshold alerts, failed CI, server down | no alerts; everything else works |
| "DevWidgets added items that can run in the background" (Login Items) | the app starts at login so the widgets keep updating | turn it off in Settings › General or System Settings › General › Login Items |
| Access to files in Documents, Desktop or Downloads | the project folder you chose is inside one of them, and `git` runs there | the Git part of the context widget stays empty |
| Find devices on your local network | an SSH server you added is on your local network | that server shows as unreachable |
| Keychain access for `gh` | `gh` keeps its token in the Keychain | GitHub through `gh` stops; a token saved in devwidgets still works |

The app is not sandboxed because the App Sandbox does not allow
listing or quitting other processes. The widget extension is
sandboxed: it only reads the shared files and passes your taps to the
app.
