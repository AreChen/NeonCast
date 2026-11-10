from pathlib import Path
import xml.etree.ElementTree as ET
from lupa.lua51 import LuaRuntime

ROOT=Path(__file__).resolve().parents[1]

def manifest():
    return [line for line in (ROOT/'NeonCast.toc').read_text().splitlines() if line and not line.startswith('#')]

def test_manifest_and_lua51_syntax():
    lua=LuaRuntime(unpack_returned_tuples=True)
    compile=lua.eval('function(s,n) local f,e=loadstring(s,n);return f~=nil,e end')
    for name in manifest():
        path=ROOT/name
        assert path.is_file(), name
        if path.suffix=='.lua':
            ok,error=compile(path.read_text(encoding='utf-8-sig'),name)
            assert ok,error
        elif path.suffix=='.xml':
            ET.parse(path)

def test_assets_and_no_network_latency_reading():
    assert all((ROOT/'Media'/f'{name}.tga').is_file() for name in ['NeonBack','NeonRing','NeonGlow'])
    for name in manifest():
        if name.endswith('.lua'):
            assert 'GetNetStats' not in (ROOT/name).read_text()
