# Modules and localization

The TOC is the load-order contract. Modules exchange explicit services through the private addon namespace (`ns`); only the two functions required by `Bindings.xml` are exported as addon globals.

| File | Responsibility |
| --- | --- |
| `Locale.lua`, `Locales/*.lua` | Language registration, complete English fallback and active translations |
| `Data.lua`, `Modules/Spells.lua` | Spell metadata, local client spell names, school detection and caches |
| `Modules/Config.lua` | Defaults, ranges, validation, colors and explicit game-queue access |
| `Modules/Profiles.lua` | Saved-variable migration, shared settings, input-mode selection and independent geometry |
| `Modules/CraftProgress.lua` | Batch counters |
| `Modules/CastResponse.lua` | Cast GUID/sample pairing and missing-sample display |
| `Modules/Bar.lua` | Textures, gradients, ticks, fonts, pixel alignment, preview and dragging |
| `Modules/Cast.lua` | Cast/channel lifecycle, fading and synthetic cast fallback |
| `Core.lua` | Event registration and dispatch |
| `UI/Theme.lua` | Shared visual tokens, five accent presets, surfaces, button skins and focus rings |
| `UI/Navigation.lua` | Native gamepad focus lifecycle; no persistent binding mutation |
| `UI/Widgets.lua`, `Options.lua` | Reusable controls and settings panel composition |
| `Minimap.lua`, `Bindings.xml` | Settings entry points |

## Add a language

1. Copy `Locales/enUS.lua` into `Locales/<clientLocale>.lua` (for example, `deDE.lua`). Change the first argument of `ns.Locale.Register` to that client locale.
2. Translate values, preserving keys and all formatting placeholders (`%s`, `%d`). Do not translate media paths or API identifiers. Labels, help, commands' output and binding names all come from the active language table.
3. Add the file to `NeonCast.toc` **before** `Locales/Init.lua`. Keep English first. No changes to widget, cast or configuration code are needed.
4. Run tests and add the locale to the completeness check in `tests/test_locales.py`. Unknown client locales and missing translated keys fall back to English. When introducing a new key, add it to English and each supported language.

Spell names and schools are separate from interface translations: `Modules/Spells.lua` resolves localized names through the client API and reads localized spell descriptions when needed.

## Saved variables

`NeonCastDB.schemaVersion = 1` stores shared appearance in `config`; `layouts.keyboard` and `layouts.gamepad` store geometry and `pos`. `layoutMode` is `auto`, `keyboard` or `gamepad`. Legacy `config` geometry and `pos` migrate once into the keyboard layout. Existing internal `latency*` setting keys are retained for migration compatibility; they refer to **cast response**, never network ping.

## In-game verification

Automated tests use the actual TOC and handlers but simulate the UI. Before releasing, verify on the current Forever client:

- Upgrade an existing character, reload, and switch between native gamepad and keyboard UI; each layout must retain its settings.
- Open settings using a bound controller button; navigate tabs, toggles, +/- controls, color presets and font cycling, then return to gameplay and other windows without losing focus.
- Open and close the color picker and any font dropdown; check focus returns to settings.
- Enter combat with preview/settings open, then leave combat and reopen. Check for Lua errors, blocked actions and leftover navigation bindings.
- Cast, channel, cancel, interrupt, chain casts and manufacture multiple items. Compare response samples with the reported event sequence, including missing samples.
- Check UI scales, small screens, translated text and changing resolutions; confirm the queue reset is the only reset that changes `SpellQueueWindow`.
