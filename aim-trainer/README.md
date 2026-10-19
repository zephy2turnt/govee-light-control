# AIM RANGE

An aim trainer for Roblox. Every player gets a private booth with their own
targets, and a precise first-person camera with raw mouse input. Personal
bests and global top-10 leaderboards are saved per mode.

## Modes

| Mode | Skill | How it works |
|---|---|---|
| **Gridshot** | speed | 3 targets on a 5×5 grid, 60s. Hit one and another appears. |
| **Flick** | reaction | 1 target anywhere on the wall, 60s. |
| **Microshot** | precision | 1 tiny target in a small area, 60s. |
| **Tracking** | smoothness | keep your crosshair on a strafing target, 45s. No clicking. |

**Scoring:** click modes give 100 per hit × your accuracy, so spamming doesn't
pay. Tracking scores the percentage of time on target, out of 10,000.

## Controls

| | PC | Gamepad | Touch |
|---|---|---|---|
| Aim | mouse | right stick | drag the screen |
| Shoot | left click | R2 | FIRE button |
| Quit round | Backspace | B | X button |

## Settings

- **General:** sensitivity (degrees per pixel), field of view, volume.
- **Crosshair shape:** horizontal lines, vertical lines, centre dot and black
  outline (each on/off); line length, thickness, gap from the centre,
  rotation (45° turns + into ×), and dot size.
- **Crosshair color:** quick presets or any colour with R/G/B sliders.

A live preview updates as you change things. Everything is saved to your
profile.

## Saving and anti-cheat

Targets and hit detection run on the client, so shooting is instant. The
server only accepts a result if:

- it comes with a one-time token from the start of that round,
- the round lasted as long as the mode takes, and
- the numbers are humanly possible for the mode: hits ≤ shots, a cap on hits
  per second, and reaction times above 80ms (`Modes.validate`).

Only then can it become a personal best or reach the leaderboard. This
blocks obvious cheating, but because aiming runs on the client, a determined
cheater could still submit a fake result that stays inside those limits.

Saving needs a **published** place with **Game Settings → Security → Enable
Studio Access to API Services** turned on. Without it, the game runs but
nothing saves and leaderboards stay empty.

## Project layout (where each script goes in Studio)

**ReplicatedStorage > Shared**
- `Modes`: mode tuning, scoring, result validation, default settings
- `Sounds`: sound IDs (official Roblox and licensed-library assets)

**ServerScriptService > Server** (Script)
- `Server`: booth assignment, round tokens, result checks, remotes
- `Range`: builds the 8 booths
- `Data`: profiles, personal bests, leaderboards

**StarterPlayer > StarterPlayerScripts > Client** (LocalScript)
- `Client`: menu → countdown → round → results flow, input
- `AimCamera`: raw-input first-person camera
- `Round`: targets, hits, combos, reaction times, tracking
- `Crosshair`, `Hud`, `Menu`, `Results`, `SettingsPanel`: screens
- `Ui`: buttons, panels, sliders, scaling; `Audio`, `Settings`

Set **Max Players to 8** in Game Settings. There are 8 booths.

## Running it

```sh
rojo build default.project.json -o AimRange.rbxlx
```

Open `AimRange.rbxlx` in Studio and press Play.
