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


def test_keybindings_use_dedicated_loader_and_are_packaged(tmp_path):
    import runpy
    from zipfile import ZipFile

    # A TOC entry sends bindings through the UI parser, which rejects Binding/name/header.
    assert 'Bindings.xml' not in manifest()
    bindings = ET.parse(ROOT/'Bindings.xml').getroot()
    assert bindings.tag == 'Bindings'
    assert {node.attrib['name'] for node in bindings} == {'NEONCAST_OPTIONS', 'NEONCAST_PREVIEW'}
    package = runpy.run_path(str(ROOT/'tools/package.py'))['package']
    archive = package(tmp_path/'NeonCast.zip')
    with ZipFile(archive) as zip_file:
        assert zip_file.read('NeonCast/Bindings.xml') == (ROOT/'Bindings.xml').read_bytes()
        assert 'Bindings.xml' not in zip_file.read('NeonCast/NeonCast.toc').decode().splitlines()
