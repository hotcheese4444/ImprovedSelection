# Improved Selection

## Selection Categories (Air only)

Four hotkeys for air combat management.
"Select Fighters" selects all friendly fighters, excluding any that are currently excluded.
"Select Bombers" selects all friendly bombers, excluding any that are currently excluded.
"Select Gunships" selects all friendly gunships, excluding any that are currently excluded.
"Exclude / Include Air Combat from Selection" toggles whether the selected fighters, gunships, and bombers are excluded from the selection hotkeys.
If any selected unit is already excluded, all selected units are included again.
Requires: ReUI

## Selection Categories (Onscreen Only)

When triggering the selection hotkeys, alive, onscreen matching units are selected. Units assigned to any
control group are excluded, including units added through the custom bindings below.

1. **Select all onscreen mml/sniper**
   - Matches: `(MOBILE * SILO * BUILTBYTIER3FACTORY * LAND) + SNIPER`
2. **Select all onscreen directfire**
   - Matches: `MOBILE * LAND * DIRECTFIRE * BUILTBYTIER3FACTORY - ENGINEER - SNIPER`
3. **Select all onscreen land AA**
   - Matches: `MOBILE * LAND * ANTIAIR - DIRECTFIRE - ENGINEER`
4. **Select all onscreen shields/deceivers**
   - Matches: `(BUILTBYTIER3FACTORY * STEALTHFIELD * MOBILE - EXPERIMENTAL) + (MOBILE * SHIELD * BUILTBYTIER3FACTORY * LAND - DIRECTFIRE)`

## Custom Bindings

You can add any selected units to the these categories dynamically through additional hotkeys. If a unit that by default fits into one of the four categories, joins another one, it will not be selected by its original category:

- **Add selected units to MML/Sniper selection**
- **Add selected units to Direct Fire selection**
- **Add selected units to Land AA selection**
- **Add selected units to Shields/Deceivers selection**

Requires: ReUI
