from support import addon

def test_migration_preserves_legacy_geometry_and_keeps_gamepad_separate():
    lua, ns=addon(saved='{config={width=280,height=25,fontSize=15,showIcon=false,fillOpacity=.6},pos={x=40,y=-210}}')
    assert ns.CONFIG.width == 280
    assert not ns.CONFIG.showIcon
    assert ns.GetPosition() == (40,-210)
    assert lua.globals().NeonCastDB.pos is None
    ns.Profiles.SetMode('gamepad')
    assert ns.CONFIG.width == 300
    assert ns.CONFIG.fontSize == 16
    assert ns.CONFIG.showIcon
    assert ns.CONFIG.fillOpacity == .6
    ns.SetPosition(100,-150)
    ns.SetSetting('width',350)
    ns.Profiles.SetMode('keyboard')
    assert ns.CONFIG.width == 280
    assert ns.GetPosition() == (40,-210)
    assert not ns.CONFIG.showIcon
    ns.Profiles.SetMode('gamepad')
    assert ns.CONFIG.width == 350
    assert ns.GetPosition() == (100,-150)
    ns.Profiles.Initialize()
    assert ns.CONFIG.width == 350
    assert ns.GetPosition() == (100,-150)


def test_automatic_transition_and_manual_override():
    lua, ns=addon()
    ns.SetSetting('width',270)
    lua.execute("gamepad=true;dispatch('INPUT_DEVICE_INTERFACE_TRANSITION')")
    assert ns.Profiles.active == 'gamepad'
    assert ns.CONFIG.width == 300
    ns.Profiles.SetMode('keyboard')
    lua.execute("dispatch('INPUT_DEVICE_INTERFACE_TRANSITION')")
    assert ns.Profiles.active == 'keyboard'
    assert ns.CONFIG.width == 270
    ns.Profiles.SetMode('auto')
    assert ns.Profiles.active == 'gamepad'


def test_reset_preserves_other_layout_and_game_queue():
    lua, ns=addon()
    ns.SetSetting('width',275)
    ns.Profiles.SetMode('gamepad')
    ns.Profiles.LargePreset()
    assert ns.CONFIG.width == 320
    ns.RestoreDefaults()
    assert ns.CONFIG.width == 300
    assert ns.IsDefault()
    assert lua.globals().queueWindow == 270
    ns.Profiles.SetMode('keyboard')
    assert ns.CONFIG.width == 275


def test_ui_mode_detection_falls_back_without_optional_helpers():
    lua, ns=addon()
    lua.execute('InputUtil=nil;C_InputInterfaceStyle={GetCurrentStyle=function() return 1 end};Enum={InputDeviceInterfaceType={Gamepad=1}}')
    ns.Profiles.UpdateMode()
    assert ns.Profiles.active == 'gamepad'
    lua.execute('C_InputInterfaceStyle=nil')
    ns.Profiles.UpdateMode()
    assert ns.Profiles.active == 'keyboard'


def test_valid_swapped_colors_survive_reload():
    lua, ns=addon(saved='{config={queueColor="white",latencyColor="red"}}')
    assert ns.CONFIG.queueColor == 'white'
    assert ns.CONFIG.latencyColor == 'red'
    ns.Profiles.SetMode('gamepad')
    assert ns.CONFIG.queueColor == 'white'
    assert ns.CONFIG.latencyColor == 'red'
