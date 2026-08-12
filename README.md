# termux-root-bridge

[English](README.md) · [Deutsch](README.de.md) · [Español](README.es.md)

Run a persistent Ubuntu environment (via [proot-distro](https://github.com/termux/proot-distro)) in Termux on the Hisense A9, start and stop it with a widget, and request **real Android root commands** from that Ubuntu session with deliberate manual confirmation for each request.

It is intended for anything developed or run in a Termux/proot environment (for example, AI coding agents such as Claude Code) that occasionally needs real device root access (system settings, `/sys` nodes, and so on).

## Why not simply use `su` from proot-distro?

It does not work reliably. `proot` intercepts system calls through `ptrace`, while Magisk's `su` communicates with the `magiskd` daemon through its own RPC/socket mechanism. Two ptrace-like layers collide (`write failed: Broken pipe` in a direct test call). This is an architectural limitation of proot, not a configuration problem.

## Architecture

```
Ubuntu session (proot-distro)          Outside proot (normal Termux)
────────────────────────────           ───────────────────────────────
androidsu "<command>"                  root-bridge-watch.sh (background loop)
  writes a request to                    detects a new request
  ~/.rootbridge/req-<id>.txt              │
  waits for a response                    ▼
                                        tmux display-popup
                                          → root-bridge-confirm.sh <id>
                                             displays the command, read -t 10 "y"?
                                             yes  → su -c "<command>" (real root)
                                             no/timeout → rejected
                                             writes the result to
                                             ~/.rootbridge/res-<id>.txt
  reads the response and returns
  the exit code and output
```

`su` is called exclusively outside proot—never inside it. The client (`androidsu`, running in proot) performs no privileged operation; it only does file I/O. All privilege escalation happens in a process that is never under proot's ptrace layer.

**Why use `tmux display-popup` instead of a second tmux window?** If your only access is a homescreen widget toggle (with no convenient way to switch windows inside tmux), the confirmation appears as an overlay **directly over the currently visible window**—no window switch is required.

## Security model

There is no new trust boundary: everything running in the Ubuntu session already has full Termux app permissions. The new capability is the additional ability to request real Android root actions with manual confirmation for each command. Every request shows the exact command text, and only a deliberate `y` input (not Enter or an empty input) starts execution. A timeout is treated as a rejection.

## Installation

Requirements: Termux, `proot-distro` with an Ubuntu distribution installed, `tmux` (≥ 3.2 for `display-popup`), and root access (for example Magisk) with Termux approved as a superuser app.

```sh
mkdir -p ~/bin ~/.shortcuts
cp scripts/ubuntu-toggle.sh scripts/androidsu scripts/root-bridge-watch.sh scripts/root-bridge-confirm.sh ~/bin/
chmod 700 ~/bin/ubuntu-toggle.sh ~/bin/androidsu ~/bin/root-bridge-watch.sh ~/bin/root-bridge-confirm.sh
cp ~/bin/ubuntu-toggle.sh "~/.shortcuts/Ubuntu Toggle"   # for Termux:Widget
```

Add `androidsu` to the PATH inside the proot-distro distribution (the container's `~/.bashrc`, not Termux's):

```sh
echo 'export PATH="/data/data/com.termux/files/home/bin:$PATH"' >> ~/.bashrc
```

Install Termux:Widget (for example from [GitHub](https://github.com/termux/termux-widget/releases) or F-Droid—it must match the signature family of your Termux installation) and place the `Ubuntu Toggle` widget on the homescreen.

**Note:** File permissions and SELinux context must match your Termux app UID (`id -u` in Termux, SELinux category via `ls -Z ~`). The exact values vary by installation and are not hard-coded here.

## Usage

```sh
# On the homescreen: tap the Ubuntu Toggle widget (starts/stops Ubuntu).
# In the Ubuntu session:
androidsu id
# → A popup appears; confirm with 'y' + Enter (10-second window)
# → uid=0(root) gid=0(root) ...
```

## Reference / inspiration

[hisense-a9/PatchingService](https://github.com/hisense-a9/PatchingService) shows that IPC across proot to a root process is possible in principle (there, a native daemon uses an abstract Unix socket for E Ink control commands). This project uses file polling instead of a socket for simplicity—for an occasional, manually confirmed use case, the latency difference is irrelevant.
