# DEPTHS: RISE OR DIE (prototype)

You're trapped at the bottom of a chasm and green necro-fog is rising. The
only way out is up, with a grappling hook that yanks you toward anchors and
flings you with all that speed when you let go.

This first build exists to answer one question: **does the grapple feel
fun?** It has one biome (the Catacombs of the Damned), the rising fog, and
the round loop. Everything is built from code.

## Controls

| | PC | Gamepad | Touch |
|---|---|---|---|
| Grapple (hold) | Left mouse or Q | R2 | HOOK button |
| Aim | mouse cursor | screen centre | screen centre |
| Move / steer in air | WASD | left stick | thumbstick |

- Aim at a glowing green orb. The best one near your aim gets a reticle.
- **Hold** to fire the rope and get pulled in. **Let go** to fling.
- You have **3 hooks**. Touching the ground refills them.
- **Gargoyles** hold for only 1.5 seconds before they shatter. Iron rings
  and stone posts are solid.
- Reach the glowing gate at the top to escape.

## Round loop

1. **Intermission** (6s): everyone spawns on the chasm floor.
2. **Climb**: the fog starts rising after 8s and speeds up over time. Touch it
   and you're consumed. Reach the gate to escape to the sanctum above.
3. **Drain**: the fog sinks back down and the next climb starts.

## Tuning the feel

Every number is in `src/shared/Config.luau`. The ones that matter most:

| Setting | Effect |
|---|---|
| `Grapple.PullAccel` | how hard the rope yanks you (higher = snappier) |
| `Grapple.MaxSpeed` | top speed while pulling |
| `Grapple.ReleaseBoost`, `ReleaseLift` | the fling when you let go |
| `Grapple.AirDrag` | how long you keep speed after letting go (lower = floatier) |
| `Grapple.AimCone`, `TouchAimCone` | how forgiving aim assist is |
| `Fog.Rate`, `Fog.Accel` | how fast the fog rises and speeds up |
| `SpeedFX.Start`, `Full`, `MaxFOV` | when wind lines and FOV kick appear |

## Project layout (where each script goes in Studio)

**ReplicatedStorage > Shared**
- `Config`: all tuning numbers
- `Sounds`: every sound ID (official licensed Roblox libraries)
- `Fog`: the fog height formula, shared so client visuals and server kills always agree

**ServerScriptService > Server** (Script)
- `Server`: round loop, fog kills, escapes, grapple validation
- `Catacombs`: builds the map from Terrain and parts
- `Anchors`: rings, posts, and crumbling gargoyles

**StarterPlayer > StarterPlayerScripts > Client** (LocalScript)
- `Grapple`: aim assist, rope, pull/fling physics, charges
- `SpeedFX`: wind lines, FOV, wind sound, landing thud
- `FogFX`: fog visuals, heartbeat, drums, danger vignette
- `CameraFX`: shared FOV and shake
- `Ropes`: draws other players' ropes
- `Hud`: status, depth meter, charges, toasts, touch controls
- `Audio`: sound playback

## Running it

Build with [Rojo](https://rojo.space) 7.4+:

```sh
rojo build default.project.json -o DepthsRiseOrDie.rbxlx
```

Open it in Roblox Studio and press **Play**. The map takes a few seconds to
generate on start. To see other players' ropes, use Test → Clients and
Servers with 2 players.

## Not in this build yet

Chunk stacking, the other biomes and hazards, ghouls, gems and the shop,
wall-running, the friend catch, and saving.
