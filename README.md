# NeonCast

**English** | [繁體中文](README.zh-TW.md)

NeonCast is a player cast bar addon for World of Warcraft Forever. It is based on Kefer's ChromaCast and retains its MIT license (see [LICENSE](LICENSE)).

## Installation and usage

Extract the `NeonCast` folder into `Interface/AddOns/NeonCast`. Disable ChromaCast to avoid overlapping cast bars. Type `/neoncast` or `/nc` to open settings, and drag the cast bar to reposition it. Settings and positions are saved per character.

## Features

- A HunterSuite-inspired cast bar and settings window with glow, a customizable theme, and color pickers.
- Controls for spacing, opacity, icon size, fonts, positioning, spell queue, latency indicators, and tick marks.
- Crafting batch progress when the client provides a valid quantity and the recipe ID matches the spell ID.
- A localized label for the `Opening - No Text` interaction spell.
- Optional, customizable latency text based on the estimated time from the cast-change event to cast start. When a measurement is unavailable, the displayed value is not updated; it is cleared when the bar hides. A displayed `0 ms` does not mean zero network latency.
- English, Traditional Chinese, and Simplified Chinese interface text, with some help text still in English.

The addon targets the Forever client. Actual event availability can vary by action, including quest items.

## Testing

Install `lupa` and `pytest` for Python and run `python -m pytest tests`. Automated tests do not replace in-game testing.
