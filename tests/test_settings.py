from support import addon

def test_visual_settings_are_validated_saved_and_reset():
    lua, ns = addon()
    ns.SetSetting('cardPadding', 100)
    assert ns.CONFIG.cardPadding == 22
    assert lua.globals().NeonCastDB.config.cardPadding == 22
    ns.SetSetting('iconScale', .1)
    assert ns.CONFIG.iconScale == .5
    ns.SetSetting('fillOpacity', .55)
    assert ns.CONFIG.fillOpacity == .55
    ns.SetSetting('showGlow', False)
    assert not ns.CONFIG.showGlow
    ns.RestoreDefaults()
    assert ns.CONFIG.cardPadding == 9
    assert ns.CONFIG.showGlow
    assert lua.globals().queueWindow == 270

def test_custom_indicator_colors_are_saved_and_validated():
    lua, ns = addon()
    color=lua.table_from({'r': .2,'g': .4,'b': .7})
    ns.SetSetting('queueColor',color)
    assert ns.GetPartColor('queueColor') == (.2,.4,.7,.4)
    ns.SetSetting('queueColor',lua.table_from({'r':2,'g':0,'b':0}))
    assert ns.CONFIG.queueColor.r == .2
    ns.RestoreDefaults()
    assert ns.CONFIG.queueColor == 'red'

def test_opening_spell_label_and_response_options():
    lua, ns = addon()
    assert ns.DisplayCastName('Opening - No Text',22810) == 'Opening'
    assert ns.DisplayCastName('Fireball',133) == 'Fireball'
    ns.SetSetting('latencyFontSize',18)
    assert ns.CONFIG.latencyFontSize == 18
    ns.SetLatencyFont(' Fonts/Test.ttf ')
    assert lua.globals().NeonCastDB.latencyFont == 'Fonts/Test.ttf'
    ns.RestoreDefaults()
    assert lua.globals().NeonCastDB.latencyFont is None

def test_invalid_saved_values_and_nonfinite_settings_are_sanitized():
    lua, ns = addon(saved='{config={width="bad",fontSize=90,queueColor={},showGlow="true"},pos={x="bad",y=0},accent={r=1}}')
    assert ns.CONFIG.width == 240
    assert ns.CONFIG.fontSize <= ns.CONFIG.height-3
    assert not ns.CONFIG.showGlow
    assert lua.globals().NeonCastDB.accent is None
    ns.SetSetting('width',float('nan'))
    assert ns.CONFIG.width == 240


def test_services_do_not_leak_internal_functions_into_global_namespace():
    lua, ns=addon()
    for key in ['ApplyColor','ApplySettings','Refresh','SetTicks','SetPixelPos','CreateBar']:
        assert lua.globals()[key] is None, key
    assert lua.globals().NeonCast_ToggleOptions is not None
