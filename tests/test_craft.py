from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def load():
    lua = LuaRuntime(unpack_returned_tuples=True)
    path = ROOT / 'CraftProgress.lua'
    if not path.exists():
        return None
    namespace = lua.table()
    lua.execute('return function(...) ' + path.read_text(encoding='utf-8') + '\nend')('NeonCast', namespace)
    return namespace.CraftProgress

def test_batch_progress_and_cancel():
    c = load()
    assert c is not None, 'craft progress is not implemented'
    c.Begin(42, 3)
    assert c.Label(42) == '1/3'
    c.Succeeded(42)
    assert c.Label(42) == '2/3'
    c.Reset()
    assert c.Label(42) is None

def test_single_unknown_and_different_spell():
    c = load()
    assert c is not None, 'craft progress is not implemented'
    c.Begin(42, 1)
    assert c.Label(42) is None
    c.Begin(42, 3)
    assert c.Label(43) is None
    c.Begin(42, None)
    assert c.Label(42) is None
