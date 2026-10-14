# Vendored libraries

Third-party code copied in as-is. Don't edit these files; to update, re-copy
them from upstream. Rojo maps them to **ReplicatedStorage > Packages**.

| Folder | Source | Commit | License |
|---|---|---|---|
| `obsidian/` | https://github.com/deividcomsono/Obsidian | d62041e | MIT |
| `lucide/` | https://github.com/notpoiu/lucide-roblox-direct (`source.lua`) | main as of 2026-10-14 | see `lucide/LICENSE` |

Only the parts that work in a normal Roblox game are included:

- `Library.lua`: the UI library itself.
- `Library.d.luau`: type definitions, for editor autocomplete only.
- Lucide icons: the library normally downloads these with `loadstring`/`HttpGet`, which don't exist in a normal game. Bundling the module and passing it to `Library:SetIconModule` gives you the icons anyway.

Not included: `SaveManager` and `ThemeManager`. They save configs with
`writefile`/`readfile`, which only exist in executors. Use the game's
DataStore saving instead.
