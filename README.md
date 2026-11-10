# NeonCast

**English** | [简体中文](README.zh-CN.md) | [繁體中文](README.zh-TW.md)

NeonCast is a personal cast bar for World of Warcraft Forever, based on Kefer's ChromaCast under the MIT license.

## Installation and use

Place the `NeonCast` folder in `Interface/AddOns/NeonCast` and disable ChromaCast to avoid overlapping bars. Open settings with `/nc`, `/neoncast`, or the minimap button. Settings are saved per character.

Opening settings keeps live casts visible. Enable **Preview / move bar** to show a demo and drag the bar; closing settings or entering combat ends preview. X/Y controls can also move the bar without dragging. The settings panel scales to the available screen size.

The bar provides school colors, theme presets and custom colors, glow, spell icons, remaining time, channel ticks, crafting batch counts, and spell queue indicators. Crafting counts require a valid batch quantity and a matching recipe/spell ID; unsupported cases show no guessed count.

**Cast response** is the estimated time from the cast-change event to the matching cast-start event, displayed as text and/or a response zone. It does not read or display network ping. `-- ms` means no sample is available for this cast; `0 ms` can reflect timing resolution. Font, size and color are configurable. SharedMedia fonts are optional.

**Restore defaults** resets the shared addon appearance and current layout, preserving the other layout and the game's spell queue setting. Resetting the game queue to 400 ms is a separate button on the Casting page.

## Native gamepad UI

- Automatic layout mode follows the game's active interface style. Keyboard/mouse and gamepad each save their position, dimensions, icon size/visibility and font sizes. Existing settings migrate to the keyboard layout. Appearance and response font selection remain shared.
- Choose Automatic, Keyboard & mouse, or Gamepad in the sidebar to override layout selection; an accented chip marks the selected mode. The active layout label shows which layout you are editing. A large-text preset applies to the current layout.
- With Forever's native gamepad UI active, the panel joins the client's focus/navigation manager. Use its direction, confirm and back controls to navigate and activate buttons. Use `-`/`+` controls for numerical adjustments; Shift or the native HUD modifier increases their step tenfold. Preset color buttons and previous/next font buttons avoid text entry for common changes.
- The game's keybinding settings include **Open / close NeonCast settings** and **Toggle NeonCast preview**. No bindings are assigned or overwritten automatically.
- Settings cannot open in combat. Missing native navigation helpers leave mouse operation available. Gamepad focus, combat restrictions and coexistence with other windows still need in-game validation on the current Forever build; simulated tests cannot certify those client behaviors.

## Development

```sh
python -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements-dev.txt
python -m pytest tests -q
python tools/package.py
```

The tests load the actual TOC sequence with a strict simulated UI, verify migrations and cast-event flows, and compile all Lua files using Lua 5.1. Panel lifecycle tests also run on Lua 5.5. GitHub Actions runs the suite on pushes and pull requests. The package command produces `dist/NeonCast.zip` with the addon folder at its root.

See [module and translation guide](docs/DEVELOPMENT.md) for module boundaries and adding a language.
