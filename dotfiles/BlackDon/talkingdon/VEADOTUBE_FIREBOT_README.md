# Veadotube Mini → Firebot state/talk-face switcher

## What it does

Switches the **active avatar state** in Veadotube Mini from an external trigger.
In Veadotube Mini, each *state* holds its own set of images — **closed mouth**, **open mouth**
(the talking face), closed‑blink, and open‑blink. So swapping the talking face is the same
thing as switching which state is active.

This script connects to Veadotube Mini's built‑in **state‑switcher web server** (the same one
its "Web Browser" remote uses), lists the available states, and fires a `set` command to switch.

## Files

- `veadotube-set-state.js` — the Firebot custom script.
  Placed at `~/.config/Firebot/v5/profiles/Main/scripts/veadotube-set-state.js`.
- Writes a debug log to `~/.config/Firebot/v5/logs/veadotube-state-debug.log`.

## Part 1 — Set up your avatars in Veadotube Mini

The script only *switches* states; it cannot create them. So first, build one state per
talking face:

1. Open your avatar in Veadotube Mini.
2. In the **States** panel, create a state for each face you want to switch to, e.g.:
   - `agree` — the normal/agree face (the current one)
   - `2` — talking face using `2.png`
   - `3` — talking face using `3.png`
3. For each state, set its **open mouth** image to the corresponding file
   (`2.png`, `3.png`, …) and its **closed mouth** image if you want a mouth‑closed variant.
4. Name the states exactly — the script matches the name case‑sensitively.

The state names are the strings you'll pass to Firebot. To list the current state names at
any time, run the script with `state` left blank or set to `list`.

## Part 2 — Add the script to Firebot

1. In Firebot v5, open **Settings → Scripts → Custom Scripts** and add/import
   `veadotube-set-state.js` (the file is already in the scripts folder).
2. Give it any display name.

## Part 3 — Make commands to switch faces

Create a **command** (or button) that runs the custom script via a
**"Run Custom Script"** effect.

Example — switch to the `2` face:

| Parameter | Value |
|-----------|-------|
| state     | `2`    |
| connectionName | `Firebot` |
| port      | *(leave blank — auto‑detected)* |

Make a second command with `state = 3` for the other face, and so on.

Tips:
- If you run it with `state` blank (or `list`), the effect reports back the available state
  names — handy for checking you've spelled a name right.
- Set the effect's **name** to something readable so it shows up in the activity log.

## How port discovery works

Veadotube Mini's IPC/state‑switch server uses a **different port every launch**, so the script
finds it automatically:

1. If you supplied the `port` parameter, it uses (and verifies) that.
2. It reads the live listener via `ss -tlnp | grep veadotube`.
3. It parses the newest log under `~/.veadotube/logs/` for `serving at 127.0.0.1:<port>`.

It verifies the port is actually accepting connections before trusting it, so a stale port
from a previous session is ignored. You only need to set `port` manually if Veadotube Mini's
listener isn't visible to `ss` or the log is missing.

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `Could not find a running Veadotube Mini instance` | Make sure Veadotube Mini is open. |
| `State "X" not found in Veadotube. Available: …` | Name doesn't match a state exactly. Run with `state=list` to see valid names. |
| `Could not connect to Veadotube Mini` | Note the exact port auto‑detection used, then set that as the `port` parameter. |
| Nothing seems to change on screen | Remember the switch only changes the *active state*. Make sure the target state has its open‑mouth image set. Also check you're looking at the avatar with the mic/talk signal active (open mouth only shows while talking). |

## Notes

- The script uses a **dependency‑free** WebSocket client (Node's built‑in `net`/`crypto`), so it
  works inside Firebot without installing anything.
- It only ever sends `listen`/`set` — it does not modify your `.veado` project file or your images.
