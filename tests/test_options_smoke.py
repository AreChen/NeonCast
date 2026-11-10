import pytest
from support import addon
from lupa.lua51 import LuaRuntime as Lua51
from lupa.lua55 import LuaRuntime as Lua55

@pytest.mark.parametrize('runtime',[Lua51,Lua55])
def test_options_open_navigate_preview_and_close(runtime):
    lua, ns = addon(gamepad=True,runtime=runtime)
    bar=ns.GetBar()
    ns.ToggleOptions()
    assert ns.OptionsFrame.IsShown(ns.OptionsFrame)
    assert not bar.unlocked
    assert lua.globals().navShown == 1
    for key in ['layout','behavior','latencyPage','appearance']:
        # Navigation labels are font strings, not button text in the existing custom tabs.
        lua.execute("for _,f in ipairs(frames) do if f.marker and f.scripts.OnClick then f:Click() end end")
    ns.TogglePreview()
    assert bar.unlocked
    ns.ToggleOptions()
    assert not bar.unlocked
    assert lua.globals().navHidden == 1


def test_combat_closes_settings_ends_preview_and_blocks_reopening():
    lua, ns=addon(gamepad=True)
    ns.TogglePreview()
    lua.execute("combat=true;dispatch('PLAYER_REGEN_DISABLED')")
    assert not ns.OptionsFrame.IsShown(ns.OptionsFrame)
    assert not ns.GetBar().unlocked
    ns.ToggleOptions()
    assert not ns.OptionsFrame.IsShown(ns.OptionsFrame)
    lua.execute("combat=false;dispatch('PLAYER_REGEN_ENABLED')")
    ns.ToggleOptions()
    assert ns.OptionsFrame.IsShown(ns.OptionsFrame)


def test_small_screen_scales_panel_and_queue_reset_is_explicit():
    lua, ns=addon()
    lua.execute('UIParent:SetSize(800,500)')
    ns.ToggleOptions()
    assert ns.OptionsFrame.GetScale(ns.OptionsFrame)*620 <= 500-24
    lua.execute("for _,f in ipairs(frames) do if f.marker and f.scripts.OnClick then f:Click() end end")
    # Select Casting by its navigation index.
    lua.execute("local n=0;for _,f in ipairs(frames) do if f.marker then n=n+1;if n==3 then f:Click() end end end")
    lua.globals().clickText(ns.L.queueReset)
    assert lua.globals().queueWindow == 400


def test_native_navigation_lifecycle_and_unavailable_helper_fallback():
    lua, ns=addon(gamepad=True)
    ns.ToggleOptions()
    assert ns.OptionsFrame.neonNavActive
    lua.execute("gamepad=false;dispatch('INPUT_DEVICE_INTERFACE_TRANSITION')")
    assert not ns.OptionsFrame.neonNavActive
    assert lua.globals().navHidden==1
    lua.execute("gamepad=true;dispatch('INPUT_DEVICE_INTERFACE_TRANSITION')")
    assert lua.globals().navShown==2
    ns.OptionsFrame.SmartNavigationCloseHandler()
    assert not ns.OptionsFrame.IsShown(ns.OptionsFrame)
    assert lua.globals().navHidden==2
    lua.execute('GamepadMode=nil;SmartNavigation_MarkFrameIgnored=nil')
    ns.ToggleOptions()
    assert ns.OptionsFrame.IsShown(ns.OptionsFrame)


def test_controller_buttons_adjust_settings_presets_and_fonts_without_text_entry():
    lua, ns=addon(gamepad=True)
    ns.ToggleOptions()
    lua.globals().clickText(ns.L.largePreset)
    assert ns.CONFIG.fontSize==18
    # Select response page, cycle font list through buttons using actual handlers.
    lua.execute("local n=0;for _,f in ipairs(frames) do if f.marker then n=n+1;if n==4 then f:Click() end end end")
    lua.execute("LibStub=function() return {List=function() return {'Test font'} end,Fetch=function() return 'Fonts/Test.ttf' end} end")
    lua.globals().clickText(ns.L.fontNext)
    assert lua.globals().NeonCastDB.latencyFont=='Fonts/Test.ttf'
    lua.globals().clickText(ns.L.fontPrev)
    assert lua.globals().NeonCastDB.latencyFont is None
    # Move to layout, then operate a +/- button and its larger-step modifier.
    lua.execute("local n=0;for _,f in ipairs(frames) do if f.marker then n=n+1;if n==2 then f:Click() end end end")
    lua.execute("local w=ns.CONFIG.width;for _,f in ipairs(frames) do if f.kind=='Button' and f:IsVisible() and f.scripts.OnClick and f.width==26 then f:Click();break end end;assert(ns.CONFIG.width==w-1)")
    lua.execute("IsShiftKeyDown=function() return true end;local w=ns.CONFIG.width;for _,f in ipairs(frames) do if f.kind=='Button' and f:IsVisible() and f.scripts.OnClick and f.width==26 then f:Click();break end end;assert(ns.CONFIG.width==w-10)")


def test_gamepad_hud_modifier_enables_coarse_steps_without_keyboard():
    lua, ns=addon(gamepad=True)
    ns.ToggleOptions()
    lua.execute("local n=0;for _,f in ipairs(frames) do if f.marker then n=n+1;if n==2 then f:Click() end end end")
    lua.execute("GamepadMode.IsHUDBindingModifierDown=function() return true end;local w=ns.CONFIG.width;for _,f in ipairs(frames) do if f.kind=='Button' and f:IsVisible() and f.scripts.OnClick and f.width==26 then f:Click();break end end;assert(ns.CONFIG.width==w-10)")


def test_theme_selection_redraws_live_cast_and_preserves_saved_custom_accent():
    lua, ns=addon(saved='{config={},accent={r=.3,g=.4,b=.5}}')
    assert ns.Theme.Accent().r == .3
    ns.ToggleOptions()
    # Operate the appearance swatch handler, not just the palette service.
    lua.execute("for _,f in ipairs(frames) do if f.kind=='Button' and f.width==26 and f.height==26 and f:IsVisible() and f.neonFocus and f.scripts.OnClick then f:Click();break end end")
    assert lua.globals().NeonCastDB.accent.r == .2
    assert ns.Theme.Accent().b == 1
    ns.RestoreDefaults()
    ns.RefreshOptions()
    assert ns.Theme.Accent().r == .2
