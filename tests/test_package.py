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


def test_player_package_is_minimal_and_reproducible(tmp_path):
    import runpy
    from zipfile import ZipFile

    tools = runpy.run_path(str(ROOT/'tools/package.py'))
    first = tools['package'](tmp_path/'first.zip')
    second = tools['package'](tmp_path/'second.zip')
    assert first.read_bytes() == second.read_bytes()
    expected = {'NeonCast/' + name for name in manifest()}
    expected.update('NeonCast/' + name for name in (
        'NeonCast.toc', 'Bindings.xml', 'LICENSE', 'Media/NeonBack.tga',
        'Media/NeonRing.tga', 'Media/NeonGlow.tga', 'Icons/ChromaCast.tga',
    ))
    with ZipFile(first) as archive:
        assert set(archive.namelist()) == expected
        assert archive.testzip() is None
        for name in archive.namelist():
            assert archive.read(name) == (ROOT/name.removeprefix('NeonCast/')).read_bytes()


def test_release_rejects_mismatched_or_invalid_tags_before_writing_archive(tmp_path):
    import pytest
    import runpy

    package = runpy.run_path(str(ROOT/'tools/package.py'))['package']
    output = tmp_path/'invalid.zip'
    for tag in ['v999.0.0', 'latest', 'v0.3.0-beta', 'v01.2.3', '../v0.3.0']:
        with pytest.raises(ValueError):
            package(output, tag=tag)
        assert not output.exists()


def test_release_cli_emits_versioned_zip_checksum_and_matching_notes(tmp_path):
    import hashlib
    import runpy
    import subprocess
    import sys

    tools = runpy.run_path(str(ROOT/'tools/package.py'))
    version = tools['version']()
    output = tmp_path/f'NeonCast-{version}.zip'
    notes = tmp_path/'notes.md'
    subprocess.run([
        sys.executable, str(ROOT/'tools/package.py'), '--tag', 'v'+version,
        '--output', str(output), '--notes-output', str(notes),
    ], check=True)
    assert output.with_suffix('.zip.sha256').read_text() == hashlib.sha256(output.read_bytes()).hexdigest()+'  '+output.name+'\n'
    assert notes.read_text() == tools['release_notes'](version)
    assert '## [0.2.0]' not in notes.read_text()


def test_package_follows_ui_xml_dependencies_and_ignores_unreferenced_art(tmp_path):
    import runpy
    import shutil
    from zipfile import ZipFile

    project = tmp_path/'project'
    shutil.copytree(ROOT, project, ignore=shutil.ignore_patterns('.git', 'dist', '__pycache__', '.pytest_cache'))
    (project/'UI/Panel.xml').write_text('<Ui><Script file="Child.lua"/><Include file="Nested.xml"/></Ui>')
    (project/'UI/Child.lua').write_text('local _, ns = ...')
    (project/'UI/Nested.xml').write_text('<Ui><Script file="Nested.lua"/></Ui>')
    (project/'UI/Nested.lua').write_text('local _, ns = ...')
    (project/'Media/development-preview.png').write_bytes(b'not a runtime asset')
    with (project/'NeonCast.toc').open('a') as toc:
        toc.write('UI/Panel.xml\n')
    package = runpy.run_path(str(ROOT/'tools/package.py'))['package']
    package.__globals__['ROOT'] = project
    with ZipFile(package(tmp_path/'nested.zip')) as archive:
        assert {'NeonCast/UI/Panel.xml','NeonCast/UI/Child.lua','NeonCast/UI/Nested.xml','NeonCast/UI/Nested.lua'} <= set(archive.namelist())
        assert not any('development-preview' in name for name in archive.namelist())
