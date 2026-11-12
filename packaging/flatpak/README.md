# Flatpak (experimental)

`com.morsetechnologies.DevWidgets.yml` builds the GTK app on the
GNOME 49 runtime with the Swift 6 SDK extension (Swift 6.3), with no
network access during the build:

```sh
flatpak install --user flathub org.gnome.Sdk//49 \
  org.gnome.Platform//49 org.freedesktop.Sdk.Extension.swift6//25.08
flatpak-builder --user --install --install-deps-from=flathub \
  build-dir packaging/flatpak/com.morsetechnologies.DevWidgets.yml
flatpak run com.morsetechnologies.DevWidgets
```

Built, installed and run on Debian 13 (x86_64) under Xvfb; the
dashboard opens and samples the machine.

## What works inside the sandbox

Checked with `flatpak run` on that machine:

| Feature | In the sandbox |
| --- | --- |
| CPU, memory, disk, network, GPU, heat, battery | Works: `/proc` and `/sys` are the host's. |
| Process list and quitting a process | Sandbox only: the app has its own process namespace, so it lists itself and `bwrap`. |
| Listening ports | Ports are listed (the network is shared), but their owners show as "other users". |
| Git | Not available: the GNOME runtime has no `git`, so the project shows no status. |
| Docker, `gh` | Not available: neither is in the runtime. A `GITHUB_TOKEN` in the environment still works over HTTPS. |
| SSH servers | `ssh` is in the runtime and `~/.ssh` is readable; `--socket=ssh-auth` passes `ssh-agent`. A live connection from the sandbox is not checked yet. |
| Tray icon, notifications | Not checked: the test machine had no panel and no portal backend. |

`flatpak-spawn --host` (allowed by `--talk-name=org.freedesktop.Flatpak`)
reaches the host, which sees every process. Running Git, Docker and
`gh` through it, and reading host processes, is not implemented yet;
until then the `.deb` and `.rpm` are the full experience.
