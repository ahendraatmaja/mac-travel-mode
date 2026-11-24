<p align="center"><img src="assets/icon.png" width="128" alt="Travel Mode icon"></p>

# Travel Mode for Mac

Close your MacBook's lid and keep it working: long downloads, builds, AI coding sessions you
follow from your phone. Travel Mode keeps the Mac awake with the lid closed, **locks the screen
when you close it**, and tells you whether Wi-Fi is on your **iPhone Personal Hotspot**.

<p align="center"><i>One small app, one button: Turn On / Turn Off.</i></p>

## Why

macOS always sleeps when you close the lid, unless an external display is plugged in.
`caffeinate` and most "keep awake" apps only stop *idle* sleep, not lid-close sleep.
Travel Mode uses the built-in `pmset disablesleep` switch, and adds the two things you want on
the road: an automatic screen lock and a hotspot check.

## What it does

| | |
|---|---|
| **Stays awake with the lid closed** | `pmset -a disablesleep 1` while on, back to normal when off |
| **Locks on lid close** | A small background watcher locks the screen within about 2 seconds of the lid closing |
| **Hotspot check** | Shows "On your iPhone hotspot", or a warning plus a **Join** button |
| **Battery at a glance** | Shown every time you open the app |
| **Survives restarts** | If you restart while it's on, the lid lock comes back on its own |

The app asks for your Mac password (the normal macOS dialog) each time you turn it on or off.
Your password goes to macOS, never to the app.

## Install

Requires macOS 13 or later and an administrator account.

```bash
git clone https://github.com/ahendraatmaja/mac-travel-mode.git
cd mac-travel-mode
./install.sh
```

This builds **Travel Mode.app** into `~/Applications` and adds a `travel-mode` command in
`~/.local/bin`. The lock helper is compiled with `clang` from the Xcode Command Line Tools
(`xcode-select --install`). Without them, the lid lock falls back to turning the display off,
which still locks if **System Settings > Lock Screen > Require password** is set to
**Immediately**.

Nothing is downloaded at install time and nothing runs in the background while Travel Mode is off.

## Use

**App:** press Cmd+Space, type "Travel Mode", press Return. Drag it to the Dock for one-click
access. To put it in Control Center or on a keyboard shortcut, create a Shortcut with a single
"Open App: Travel Mode" action.

**Command line:**

```text
travel-mode on | off | toggle | status
travel-mode wifi              hotspot / other / off / none, plus a message
travel-mode join [name]       join your hotspot and wait until it's connected
travel-mode hotspot [name]    show or set which saved network is your hotspot
travel-mode networks          list saved Wi-Fi networks
```

The first time you press **Join Hotspot**, the app asks which saved network is your iPhone.

## How the hotspot check works

On recent macOS versions, the name of the current Wi-Fi network counts as location data and is hidden
from scripts (`<redacted>`) unless you grant Location Services. Travel Mode doesn't need it:
an iPhone or iPad Personal Hotspot always uses the `172.20.10.0/28` network with router
`172.20.10.1`. Travel Mode reads each network interface's own router address, so a VPN doesn't
confuse it.

Android hotspots use other addresses and show as "another Wi-Fi network".

## Travel tips

- **Heat:** a closed laptop in a bag has little airflow. Light work is fine; avoid long heavy
  workloads inside a tight sleeve.
- **Battery:** it never sleeps while on, even on battery. Turn it off when you arrive.
- **Internet:** connect to your hotspot *before* closing the lid.

## Uninstall

```bash
./uninstall.sh
```

Restores normal sleep (asks for your password if Travel Mode is on) and removes the app,
the command, the background watcher and the settings.

## Files it touches

| Path | What |
|---|---|
| `~/Applications/Travel Mode.app` | The app (the scripts live inside it) |
| `~/.local/bin/travel-mode` | Link to the command |
| `~/Library/LaunchAgents/io.github.ahendraatmaja.mac-travel-mode.lid-lock.plist` | Lid-lock watcher, only while on |
| `~/Library/Application Support/Travel Mode/hotspot-name` | Your hotspot's name |
| `~/Library/Logs/travel-mode.log` | One line each time the lid lock fires |
| System power setting `SleepDisabled` | Set to 1 while on, 0 when off |

## License

MIT
