# Grow a Brainrot

A Roblox game in the style of *Grow a Garden* and *Steal a Brainrot*: grow
brainrots from seeds, have them earn cash on your base, and steal other players'
brainrots while they try to bonk you.

Everything is built from code (the map, models and UI), so you need no
assets from Studio.

## How to play

1. **Buy seeds** at the Seed Shop in the middle of the map, or with the SHOP button.
2. **Plant** them in the 6 soil tiles on your plot. Pick which seed with the hotbar.
3. **Harvest** when the plant says READY. You get a random brainrot that sits
   on one of your 8 pedestals and earns cash every second.
4. **Sell** a brainrot (press F at its pedestal) for 30× its income.
5. **Steal** from other bases: hold E at their pedestal, then run the brainrot
   back to your own base. While you carry it you move slower.
6. **Defend**: press the red **Lock** button for 60s of protection, and use the
   **Bonk Bat** on a thief to send the brainrot home.

Rarities run Common → Rare → Epic → Legendary → Mythic → Secret. Harvests can
mutate into **Golden** (3×) or **Rainbow** (10×). Every 5 minutes a **Golden
Rain** event makes mutations 4× more likely for 60s.

Progress saves to a DataStore: cash, seeds, brainrots, and growing plants.
Plants keep growing while you're offline.

## Project layout (where each script goes in Studio)

Rojo places these automatically. If you copy them by hand, use the same layout.

**ReplicatedStorage > Shared** (Folder; ModuleScripts used by both sides)
- `Theme`: the design system (colours, fonts, radii, tweens, sound IDs, rarity colours)
- `Config`: gameplay tuning (seeds, creatures, prices, timers)

**ServerScriptService > Server** (Script, with ModuleScripts inside it)
- `Server` (`init.server.luau`): game logic plus every RemoteEvent, all validated on the server
- `MapBuilder`, `Visuals`: build the world and models
- `DataService`: DataStore load/save, including validated player settings

**StarterPlayer > StarterPlayerScripts > Client** (LocalScript, with these inside it)
- `Client` (`init.client.luau`): bootstrap; shows the menu, then starts gameplay on Play
- `UI/`: `Components` (buttons, panels, sliders), `Motion` (animations), `Sound`, `Responsive` (scaling for PC/phone/tablet)
- `Systems/`: `SettingsController`, `Graphics` (quality levels), `MenuCamera`
- `Screens/`: `MainMenu`, `SettingsScreen`
- `Hud`: the in-game HUD (the prototype HUD; it gets rebuilt on the design system next)

To restyle the whole game, edit the values in `src/shared/Theme.luau`.

## Running it

You need [Rojo](https://rojo.space) 7.4 or newer.

**Option A: open a place file**

```sh
rojo build default.project.json -o GrowABrainrot.rbxlx
```

Open `GrowABrainrot.rbxlx` in Roblox Studio and press Play.

**Option B: live sync**

Install the Rojo Studio plugin, run `rojo serve`, and click Connect in Studio.
Edits to the `.luau` files sync into Studio as you save.

To test stealing locally, use Studio's **Test → Clients and Servers** with 2+ players.

For saving to work, publish the place and turn on
**Game Settings → Security → Enable Studio Access to API Services**.
Without that the game still runs but shows a "saving is off" message.

Set **Max Players to 6** in Game Settings, because there are 6 plots. Extra
players are kicked with a "server full" message.
