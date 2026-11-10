from support import addon


def start(lua, guid='cast-1', name='Fireball', spell=133, duration=3):
    lua.globals().castGuid=guid
    lua.globals().castName=name
    lua.globals().spellId=spell
    lua.globals().duration=duration
    lua.execute("""
        dispatch('CURRENT_SPELL_CAST_CHANGED')
        dispatch('UNIT_SPELLCAST_SENT','player','target',castGuid,spellId)
        now=now+.08
        currentCast={castName,'',123,now*1000,(now+duration)*1000,false,castGuid,false,spellId}
        dispatch('UNIT_SPELLCAST_START','player',castGuid,spellId)
    """)


def test_login_cast_response_delay_interrupt_and_replacement():
    lua, ns=addon()
    bar=ns.GetBar()
    start(lua)
    assert bar.active and not bar.channel
    assert abs(bar.castLatency-.08)<.000001
    assert bar.latencyText.GetText(bar.latencyText) == '80 ms'
    lua.execute("now=now+1;currentCast[5]=currentCast[5]+500;dispatch('UNIT_SPELLCAST_DELAYED','player','cast-1',133)")
    assert abs(bar.total-3.5)<.000001
    lua.execute("currentCast=nil;dispatch('UNIT_SPELLCAST_INTERRUPTED','player','cast-1',133)")
    assert not bar.active and bar.fading and bar.failed
    start(lua,guid='cast-2')
    assert bar.active and not bar.fading and not bar.failed
    lua.execute('now=now+4;currentCast=nil;ns.Cast.OnUpdate(ns.GetBar());now=now+2;ns.Cast.OnUpdate(ns.GetBar())')
    assert not bar.IsShown(bar)


def test_opening_settings_preserves_live_cast_and_missing_samples_clear_old_number():
    lua, ns=addon()
    start(lua)
    bar=ns.GetBar()
    ns.ToggleOptions()
    assert bar.active and not bar.unlocked
    assert bar.latencyText.GetText(bar.latencyText)=='80 ms'
    lua.execute("now=now+.2;currentCast[7]='cast-no-sample';dispatch('UNIT_SPELLCAST_START','player','cast-no-sample',133)")
    assert bar.castLatency is None
    assert bar.latencyText.GetText(bar.latencyText)=='-- ms'
    ns.ToggleOptions()
    assert bar.active and not bar.unlocked


def test_channel_update_and_input_mode_transition_keep_cast_running():
    lua, ns=addon()
    lua.execute("currentChannel={'Mind Flay','',123,10000,13000,false,false,15407};dispatch('UNIT_SPELLCAST_CHANNEL_START','player','channel-1',15407)")
    bar=ns.GetBar()
    assert bar.active and bar.channel
    lua.execute("now=11;currentChannel[5]=14000;dispatch('UNIT_SPELLCAST_CHANNEL_UPDATE','player','channel-1',15407)")
    assert bar.total==4
    lua.execute("gamepad=true;dispatch('INPUT_DEVICE_INTERFACE_TRANSITION')")
    assert bar.active and bar.channel
    assert bar.GetWidth(bar)==300
    lua.execute("currentChannel=nil;dispatch('UNIT_SPELLCAST_CHANNEL_STOP','player','channel-1',15407)")
    assert not bar.active and bar.fading
