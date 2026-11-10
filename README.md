# Extra Keybinds for RuneScape: Dragonwilds

A UE4SS Lua mod for RuneScape: Dragonwilds. It gives every action in
**Settings > Controls** a second keyboard/mouse key, so two keys can do the same
thing: Space and a mouse thumb button for Jump, for example.

- Each action row gets a second key box, between the normal key and the
  controller button. Click it and press a key or mouse button, the same way you
  set the first one.
- A second key gets a small **X** at the right-hand end of its box. Click the X
  to clear that key.
- The second box is the game's own. Dragonwilds ships with it hidden and
  switched off; this mod shows it and makes room for it. Binding, the "already
  in use" question, saving and **Reset To Defaults** are all the game's code.
- Second keys are saved with your other keybinds, so they are still there after
  a restart.
- Client-side only. Other players and servers don't need it.
- Doesn't change any world settings, so achievements keep working.

Built for game build 26162923 (Unreal Engine 5.6) with UE4SS v3.0.1-1217.

## Requirements

- [UE4SS for RuneScape: Dragonwilds](https://github.com/MichaelRyan2319/RSDragonwilds-UE4SS).
  Any other UE4SS v3 install works too.

## Install with Mod Loader

[Mod Loader](https://github.com/MichaelRyan2319/ModLoader) installs the mod and
keeps it up to date.

1. **Add game** and pick RuneScape: Dragonwilds. Mod Loader 1.0.1 or later sets
   the mods folder to the game's inner `RSDragonwilds` folder (the one with
   `Binaries` and `Content` in it). If you added the game with an older version,
   edit it and choose that folder.
2. **Add mod** `MichaelRyan2319/RSDragonwilds-ExtraKeybinds`. The mod needs
   UE4SS, so Mod Loader 1.1.0 or later offers to add
   `MichaelRyan2319/RSDragonwilds-UE4SS` as well; click **Yes**. With an older
   Mod Loader, add `MichaelRyan2319/RSDragonwilds-UE4SS` yourself first.
3. Start the game and open Settings > Controls.

## Install by hand

1. Install UE4SS (see Requirements).
2. Download `ExtraKeybinds.zip` from the [Releases](../../releases) page.
   In Steam, right-click RuneScape: Dragonwilds > Manage > Browse local files,
   then open the `RSDragonwilds` folder (the one with `Binaries` and `Content`
   in it) and extract the zip there. The mod ends up in
   `Binaries\Win64\ue4ss\Mods\ExtraKeybinds`.
3. Start the game and open Settings > Controls.

The mod folder contains `enabled.txt`, so UE4SS loads it without any change to
`mods.txt`. To install from this repo instead of a release, copy the
`ExtraKeybinds` folder into `Win64\ue4ss\Mods\`.

## Settings

Edit `Win64\ue4ss\Mods\ExtraKeybinds\Scripts\config.lua` in Notepad, then restart
the game.

| Setting | Default | What it does |
| --- | --- | --- |
| `NameWidth` | `1.5` | Width of the action's name compared with one key box. Raise it if long names get cut off. |
| `PollMs` | `50` | How often the open Controls page is checked, in milliseconds |
| `DebugLogging` | `false` | Extra lines in `UE4SS.log` |

## How it works

- The game's keybind row (`WBP_KeyBindingListItem`) has three buttons:
  `KeyButton1`, `KeyButton2` and `GamepadButton`. The game collapses and
  disables `KeyButton2` every time it fills a row. While the Controls page is
  open, the mod shows and enables it again on every row that has a
  keyboard/mouse key.
- Clicking it runs the game's own `BindKey(1)`, which stores the key in the
  second slot of that action in Unreal's Enhanced Input user settings. The engine
  applies every slot of an action, so both keys work.
- Three boxes at the game's width leave no room for the action's name, so the
  mod makes the name and the boxes share the row's width.
- The X is a layer added over the row with the same columns as the row, empty
  except for one of the game's own invisible buttons (`WBP_InvisibleButton`) at
  the end of the second key's column. Its click is caught with a hook on
  `CommonButtonBase:HandleButtonClicked`. Clearing calls Enhanced Input's
  `UnMapPlayerKey` for the second slot of the action and of the names the game
  binds along with it, saves, and has the list redraw its rows.
- A row only knows its action by its text, so the mod matches that text to the
  player controller's `KeySettingsMap` to find the action. A row whose text
  matches no keyboard/mouse action, or more than one, gets no X.
- Nothing is changed on disk except the game's own keybind file
  (`%LOCALAPPDATA%\RSDragonwilds\Saved\SaveGames\EnhancedInputUserSettings.sav`),
  which the game writes itself.

### Achievements

The game skips achievement unlocks only in Creative and Custom worlds. This mod
never touches world difficulty or world settings. The game's mod check
(`CheckForMods`) logs a warning and marks the world as modded for people
joining, but achievements still unlocked in testing with other UE4SS mods.

## Troubleshooting

The log is `Win64\ue4ss\UE4SS.log`. Lines from this mod start with
`[ExtraKeybinds]`. Set `DebugLogging = true` in `config.lua` for more detail.

## Uninstall

Delete `Win64\ue4ss\Mods\ExtraKeybinds`, or remove the mod in Mod Loader.

Second keys you have already set **keep working** after the mod is gone,
because they are saved in the game's own keybind file, and the menu hides them
again. Clear them with the X before uninstalling. Without the mod, the only way
to remove them is **Reset To Defaults** in Settings > Controls, which resets
every keybind.

## Credits

UE4SS is made by the UE4SS team ([RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS),
MIT licence).
