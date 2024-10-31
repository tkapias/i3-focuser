# i3-focuser

A wrapper script that conditionally controls an application states under i3wm with a unique command line.

The [i3](https://github.com/i3/i3) tiling window manager lacks, by design, a taskbar.
To some extent, the [Scratchpad](https://i3wm.org/docs/userguide.html#_scratchpad) feature fills the gap by letting you toggle floating windows between the current workspace and a hidden one.
Also, i3 API allows to list windows in the Scratchpad or filter your actions by the window's class, instance or title, but there is no command to condition an action or a choice of actions on a state, so you can't start/quit/hide/focus a software with the same keybinding.

That is what i3-focuser aims to help you do.

## Help

```
i3-focuser will try to focus, hide or close a floating window
using x11 and i3wm's scratchpad.
Otherwise it will run a systemd service or/and a command.

Usage:
  ./i3-focuser [-h] [Options...] [-c 'pattern' [-n 'pattern']] [-m command [-s service]]
options:
  -h              Print this Help.
  -c "<WM_CLASS>" Regex pattern matching window general class.
  -n "<WM_NAME>"  Regex pattern matching window name (or title).
  -m "<command>"  Command with arguments to run if there is no match.
  -s "<service>"  Systemd service to check/start in priority if there is no match.
  -i              Use i3wm scratchpad to hide the match instead of a gracefull quit.
  -v              Match only visible windows. Can help with sorting matches.

Mandatory match:  -c and/or -n
Mandatory run:    -m and/or -s
```

## Dependencies

- [i3](https://github.com/i3/i3)
  - i3-msg
- [bonk](https://github.com/FascinatedBox/bonk)
- Systemd
- Bash >= 5
- renice
- setsid

## Installation

```bash
git clone --depth 0 https://github.com/tkapias/i3-focuser.git i3-focuser
cd i3-focuser
chmod +x i3-focuser.bash
```

- Optional: Symlink to a directory in your user's path:

```bash
ln -s $PWD/i3-focuser.bash $HOME/.local/bin/i3-focuser
```

## Usage Exemples

- Bindings in i3 config file:

``` i3
# Start Kitty terminal as a service and toggle the window in focus
# or to the scratchpad.
# Exemple of command for the systemd service:
# ExecStart=kitty --single-instance --instance-group quake --session ~/.config/kitty/session-quake.conf --name kitty --class Kitty-Quake --listen-on unix:@Kitty-Quake
bindcode $mod+49 exec --no-startup-id "i3-focuser -i -c '^Kitty-Quake$' -s kitty"

# Start the File explorer PCManFM as a command and toggle the window
# in focus or to the scratchpad.
bindsym $mod+Tab exec --no-startup-id "i3-focuser -i -c \\"^Pcmanfm$\\" -m \\"pcmanfm $HOME\\""

# Start KeepassXC passwords manager as a service and toggle the window
# from the notification area.
bindsym $mod+x exec --no-startup-id "i3-focuser -c ^keepassxc$ -n Tomasz -s keepassxc.service"

# Start the Qalculate calculator as a command and toggle the window
# in focus or to the scratchpad.
bindsym $mod+Shift+c exec --no-startup-id "i3-focuser -i -c \\"qalculate-gtk\\" -n \\"^Qalculate!$\\" -m \\"qalculate-gtk\\""
```

## Roadmap

- Alternative to bonk: xdotool and wmctrl had too much instability, but bonk is not maintained anymore, so I may look for other ways.
- Instance class filter: i3-focuser option -c match the general class of a window, but there is also an instance class that is rarely needed.
