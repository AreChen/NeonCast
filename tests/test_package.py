from pathlib import Path
from lupa import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]

def test_all_addon_lua_files_compile():
    lua = LuaRuntime(unpack_returned_tuples=True)
    compile_file = lua.eval('function(s, n) local f, err = load(s, n); return f ~= nil, err end')
    for name in ('Locale.lua', 'CraftProgress.lua', 'Data.lua', 'Core.lua', 'Options.lua'):
        ok, error = compile_file((ROOT / name).read_text(encoding='utf-8-sig'), name)
        assert ok, f'{name}: {error}'

def test_manifest_files_exist():
    manifest = (ROOT / 'NeonCast.toc').read_text(encoding='utf-8-sig').splitlines()
    for item in manifest:
        if item and not item.startswith('#'):
            assert (ROOT / item).is_file(), item
def test_neon_card_assets_are_packaged():
    core = (ROOT / 'Core.lua').read_text(encoding='utf-8-sig')
    assert 'NeonRing' in core and 'NeonGlow' in core
    assert (ROOT / 'Media' / 'NeonBack.tga').is_file()
    assert (ROOT / 'Media' / 'NeonRing.tga').is_file()
    assert (ROOT / 'Media' / 'NeonGlow.tga').is_file()
