from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def test_cast_latency_matches_guid_and_clears_stale_events():
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.table()
    lua.execute((ROOT / 'CraftProgress.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    p = ns.CastLatency
    p.Sent('first', 10)
    p.Sent('second', 10.1)
    assert abs(p.Start('second', 10.35) - 0.25) < 0.00001
    assert abs(p.Start('first', 10.45) - 0.45) < 0.00001
    assert p.Start('first', 10.5) is None
    p.Sent('expired', 10)
    assert p.Start('expired', 31) is None
    p.Sent('cancelled', 20)
    p.Forget('cancelled')
    assert p.Start('cancelled', 20.5) is None
    p.Sent(None, 21)
    assert p.Start(None, 21.1) is None

def test_clock_prefers_precise_and_sub_millisecond_is_unavailable():
    lua = LuaRuntime(unpack_returned_tuples=True)
    ns = lua.table()
    lua.execute('function GetTime() return 10 end; function GetTimePreciseSec() return 10.123456 end')
    lua.execute((ROOT / 'CraftProgress.lua').read_text(encoding='utf-8-sig'), 'NeonCast', ns)
    p = ns.CastLatency
    assert p.Now() == 10.123456
    p.Sent('same', 10)
    assert p.Start('same', 10) is None
    p.Sent('under', 10)
    assert p.Start('under', 10.0002) is None
    p.Sent('normal', 10)
    assert abs(p.Start('normal', 10.012) - .012) < .00001
    lua.execute('GetTimePreciseSec = nil')
    assert p.Now() == 10
